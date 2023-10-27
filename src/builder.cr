class SQL
  abstract struct Builder
    QUOTE_CHARACTER = '"'

    @@adapters = {} of String => Builder.class

    def self.register(name : String, klass : Builder.class)
      @@adapters[name] = klass
    end

    def self.fetch(name : String) : Builder.class
      @@adapters[name]?.not_nil! "Unknown SQL adapter: #{name}"
    end

    def self.fetch(name : Nil) : NoReturn
      name.not_nil! "Unknown SQL adapter: #{name}"
    end

    def initialize
      @sql = String::Builder.new(capacity: 256)
      @args = Array(ValueType).new
    end

    def select(query : NamedTuple) : {String, Array(ValueType)}
      @sql << "SELECT "
      if columns = query[:select]?
        to_sql_select(columns)
      else
        @sql << '*'
      end

      @sql << " FROM "
      to_sql query[:from]

      if join = query[:join]?
        case join
        in Tuple
          to_sql_join(*join)
        in Enumerable
          join.each { |j| to_sql_join(*j) }
        end
      end

      if where = query[:where]?
        @sql << " WHERE "
        to_sql_where(where)
      end

      if group_by = query[:group_by]?
        @sql << " GROUP BY "
        to_sql group_by
      end

      if having = query[:having]?
        @sql << " HAVING "
        to_sql_where(having)
      end

      if order_by = query[:order_by]?
        @sql << " ORDER BY "
        to_sql_order(order_by)
      end

      if limit = query[:limit]?
        @sql << " LIMIT " << limit.to_i
      end

      if offset = query[:offset]?
        @sql << " OFFSET " << offset.to_i
      end

      {@sql.to_s, @args}
    end

    protected def to_sql_select(columns : Hash) : Nil
      columns.each_with_index do |(column, _as), i|
        @sql << ", " unless i == 0
        to_sql column
        @sql << ".*" if column.is_a?(Table)
        if _as
          @sql << " AS "
          quote _as
        end
      end
    end

    protected def to_sql_select(columns : Enumerable) : Nil
      columns.each_with_index do |column, i|
        @sql << ", " unless i == 0
        to_sql column
        @sql << ".*" if column.is_a?(Table)
      end
    end

    protected def to_sql_select(column : Table) : Nil
      to_sql column
      @sql << ".*"
    end

    protected def to_sql_select(columns) : Nil
      to_sql columns
    end

    protected def to_sql_join(table : Table, options : NamedTuple) : Nil
      to_sql_join(:inner, table, options)
    end

    protected def to_sql_join(kind : Symbol, table : Table, options : NamedTuple) : Nil
      # TODO: validate possible options unless flag?(:release)

      case kind
      when :inner
        @sql << " INNER JOIN "
      when :left
        @sql << " LEFT JOIN "
      when :right
        @sql << " RIGHT JOIN "
      when :full
        @sql << " FULL JOIN "
      else
        raise "Expected :inner, :left, :right or :full but got #{kind.inspect}"
      end

      to_sql table

      if on = options[:on]?
        @sql << " ON "
        to_sql on
      elsif using = options[:using]?
        @sql << " USING ("
        to_sql using
        @sql << ')'
      else
        raise "Missing :on or :using option for JOIN clause"
      end
    end

    protected def to_sql_order(order_by : Hash) : Nil
      order_by.each_with_index do |(expression, direction), i|
        @sql << ", " unless i == 0
        to_sql expression
        to_sql_order_direction(direction)
      end
    end

    protected def to_sql_order(order_by : NamedTuple) : Nil
      order_by.each_with_index do |expression, direction, i|
        @sql << ", " unless i == 0
        to_sql expression
        to_sql_order_direction(direction)
      end
    end

    protected def to_sql_order_direction(direction : Tuple) : Nil
      to_sql_order_direction(*direction)
    end

    protected def to_sql_order_direction(direction : Symbol?, options : NamedTuple) : Nil
      to_sql_order_direction(direction)

      # TODO: validate possible options unless flag?(:release)

      # if using = options[:using]?
      #   if using.is_a?(Symbol)
      #     @sql << using
      #   else
      #     raise "Expected ORDER BY USING operator to be a symbol (e.g. :<, :>=) but got #{using.inspect}"
      #   end
      # end

      if nulls = options[:nulls]?
        @sql << " NULLS "
        case nulls
        when :first
          @sql << "FIRST"
        when :last
          @sql << "LAST"
        else
          raise "Expected ORDER BY NULLS option to be :first or :last but got #{nulls.inspect}"
        end
      end
    end

    protected def to_sql_order_direction(direction : Symbol) : Nil
      case direction
      when :asc
        @sql << " ASC"
      when :desc
        @sql << " DESC"
      else
        raise "Expected ORDER BY direction to be :asc or :desc but got #{direction.inspect}"
      end
    end

    protected def to_sql_order_direction(direction : Nil) : Nil
    end

    protected def to_sql_order(order_by) : Nil
      to_sql order_by
    end

    def insert(query : NamedTuple) : {String, Array(ValueType)}
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

    def update(query : NamedTuple) : {String, Array(ValueType)}
      @sql << "UPDATE "
      to_sql query[:update]

      @sql << " SET "
      to_sql_update_set(query[:set])

      if where = query[:where]?
        @sql << " WHERE "
        to_sql_where(where)
      end

      if returning = query[:returning]?
        to_sql_returning(returning)
      end

      {@sql.to_s, @args}
    end

    def delete(query : NamedTuple) : {String, Array(ValueType)}
      @sql << "DELETE FROM "
      to_sql query[:from]

      if where = query[:where]?
        @sql << " WHERE "
        to_sql_where(where)
      end

      if returning = query[:returning]?
        to_sql_returning(returning)
      end

      {@sql.to_s, @args}
    end

    protected def to_sql_where(conditions : Enumerable) : Nil
      conditions.each_with_index do |condition, i|
        @sql << " AND " unless i == 0
        nested_expression { to_sql condition }
      end
    end

    protected def to_sql_where(conditions) : Nil
      to_sql conditions
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
      nested_expression do
        to_sql binary.lhs
        @sql << ' '
        @sql << binary.operator
        @sql << ' '
        to_sql binary.rhs
      end
    end

    protected def to_sql(binary : InOperation) : Nil
      nested_expression do
        to_sql binary.lhs
        @sql << ' '
        @sql << binary.operator
        @sql << ' '
        @sql << '('
        binary.rhs.each_with_index do |arg, i|
          @sql << ", " unless i == 0
          to_sql_statement_placeholder(arg)
        end
        @sql << ')'
      end
    end

    protected def to_sql(unary : UnaryOperation) : Nil
      nested_expression do
        to_sql unary.expression
        @sql << ' '
        @sql << unary.operator
      end
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

    protected def to_sql(column : Wrap) : Nil
      quote column.name
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

    # Avoid to englob the outer-most expression between parenthesis, but makes
    # sure that any nested expression is englobed for explicit operator
    # precedence. For example:
    #
    # ```
    # WHERE a = (1 + 2) * 3
    # WHERE (a = (1 + 2) * 3) AND (b > 2)
    # ```
    protected def nested_expression(&) : Nil
      if @nested
        @sql << '('
        yield
        @sql << ')'
      else
        @nested = true
        yield
        @nested = false
      end
    end
  end
end
