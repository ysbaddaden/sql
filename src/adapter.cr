class SQL
  abstract struct Adapter
    QUOTE_CHARACTER = '"'

    @@adapters = {} of String => Adapter.class

    def self.register(name : String, klass : Adapter.class)
      @@adapters[name] = klass
    end

    def self.for(name : String) : Adapter.class
      @@adapters[name]?.not_nil! "Unknown SQL adapter: #{name}"
    end

    def initialize
      @sql = String::Builder.new(capacity: 256)
      @args = Array(ValueType).new
    end

    def select(query) : {String, Array(ValueType)}
      @sql << "SELECT "
      if columns = query[:select]?
        if columns.is_a?(Hash)
          columns.each_with_index do |(column, _as), i|
            @sql << ", " unless i == 0
            to_sql column

            if _as
              @sql << " AS "
              quote _as
            end
          end
        else
          to_sql columns
        end
      else
        @sql << '*'
      end

      @sql << " FROM "
      to_sql query[:from]

      if where = query[:where]?
        @sql << " WHERE "
        to_sql where
      end

      if group_by = query[:group_by]?
        @sql << " GROUP BY "
        to_sql group_by
      end

      if having = query[:having]?
        @sql << " HAVING "
        to_sql having
      end

      if order_by = query[:order_by]?
        @sql << " ORDER BY "

        case order_by
        when Hash
          order_by.each do |expression, direction|
            to_sql expression

            case direction
            when :asc
              @sql << " ASC"
            when :desc
              @sql << " DESC"
            else
              raise "Order by direction must be :asc or :desc but got #{direction}"
            end
          end
        else
          to_sql order_by
        end
      end

      if limit = query[:limit]?
        @sql << " LIMIT " << limit.to_i
      end

      if offset = query[:offset]?
        @sql << " OFFSET " << offset.to_i
      end

      {@sql.to_s, @args}
    end

    def insert(query) : {String, Array(ValueType)}
      @sql << "INSERT INTO "
      to_sql query[:into]

      if values = query[:values]?
        case values
        when NamedTuple, Hash
          to_sql_insert_columns(values)
          to_sql_insert_values(values)
        when Enumerable
          # TODO: BATCH INSERT
          raise NotImplementedError.new("batch insertion isn't implemented (yet)")
        else
          raise "Expected Hash or NamedTuple but got #{values.class.name}"
        end
      else
        @sql << " DEFAULT VALUES"
      end

      if on_conflict = query[:on_conflict]?
        to_sql_on_conflict(on_conflict)
      end

      if returning = query[:returning]?
        to_sql_returning(returning)
      end

      {@sql.to_s, @args}
    end

    @[AlwaysInline]
    protected def to_sql_returning(returning) : Nil
      @sql << " RETURNING "
      to_sql returning
    end

    protected def to_sql_insert_columns(values : Hash) : Nil
      @sql << " ("
      values.each_with_index do |(column, _), i|
        @sql << ", " unless i == 0
        to_sql column
      end
      @sql << ')'
    end

    protected def to_sql_insert_columns(values : NamedTuple) : Nil
      @sql << " ("
      values.each_with_index do |column, _, i|
        @sql << ", " unless i == 0
        to_sql column
      end
      @sql << ')'
    end

    protected def to_sql_insert_values(values : Hash) : Nil
      @sql << " VALUES ("
      values.each_with_index do |(_, value), i|
        @sql << ", " unless i == 0
        to_sql value
      end
      @sql << ')'
    end

    protected def to_sql_insert_values(values : NamedTuple) : Nil
      @sql << " VALUES ("
      values.each_with_index do |_, value, i|
        @sql << ", " unless i == 0
        to_sql value
      end
      @sql << ')'
    end

    def update(query) : {String, Array(ValueType)}
      @sql << "UPDATE "
      to_sql query[:update]

      @sql << " SET "
      to_sql_update_set(query[:set])

      if where = query[:where]?
        @sql << " WHERE "
        to_sql where
      end

      if returning = query[:returning]?
        to_sql_returning(returning)
      end

      {@sql.to_s, @args}
    end

    def delete(query) : {String, Array(ValueType)}
      @sql << "DELETE FROM "
      to_sql query[:from]

      if where = query[:where]?
        @sql << " WHERE "
        to_sql where
      end

      if returning = query[:returning]?
        to_sql_returning(returning)
      end

      {@sql.to_s, @args}
    end

    protected def to_sql_update_set(update : Hash) : Nil
      update.each_with_index do |(column, value), i|
        @sql << ", " unless i == 0
        to_sql column
        @sql << " = "
        to_sql value
      end
    end

    protected def to_sql_update_set(update : NamedTuple) : Nil
      update.each_with_index do |column_name, value, i|
        @sql << ", " unless i == 0
        quote(column_name)
        @sql << " = "
        to_sql value
      end
    end

    protected def to_sql(expressions : Enumerable) : Nil
      expressions.each_with_index do |expression, i|
        @sql << ", " unless i == 0
        to_sql expression
      end
    end

    protected def to_sql(binary : BinaryOperation) : Nil
      @sql << '('
      to_sql binary.lhs
      @sql << ' '
      @sql << binary.operator
      @sql << ' '
      to_sql binary.rhs
      @sql << ')'
    end

    protected def to_sql(unary : UnaryOperation) : Nil
      @sql << '('
      to_sql unary.expression
      @sql << ' '
      @sql << unary.operator
      @sql << ')'
    end

    protected def to_sql(fn : Function) : Nil
      @sql << fn.name
      @sql << '('
      if args = fn.args?
        to_sql args
      end
      @sql << ')'
    end

    protected def to_sql(table : Table) : Nil
      quote table.__table_name

      if _as = table.__table_as?
        @sql << " AS "
        quote _as
      end
    end

    protected def to_sql(column : Column) : Nil
      quote column.table_name
      @sql << '.'
      quote column.name
    end

    protected def to_sql(value : ValueType) : Nil
      to_sql_statement_placeholder(value)
    end

    protected def to_sql(value : Time) : Nil
      to_sql_statement_placeholder(value.to_utc)
    end

    protected def to_sql_statement_placeholder(value : ValueType) : Nil
      @sql << '?'
      @args << value
    end

    protected def to_sql(name : Symbol) : Nil
      quote name
    end

    protected def to_sql(raw : Raw) : Nil
      @sql << raw.sql
    end

    protected def quote(name : Symbol) : Nil
      if name == :*
        @sql << '*'
      else
        @sql << QUOTE_CHARACTER
        @sql << name.to_s.gsub(QUOTE_CHARACTER, "\\#{QUOTE_CHARACTER}")
        @sql << QUOTE_CHARACTER
      end
    end
  end
end
