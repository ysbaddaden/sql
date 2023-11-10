class SQL
  # TODO: WINDOW
  # TODO: SET column = DEFAULT
  # TODO: SET (column, ...) = (expression | DEFAULT)
  # TODO: SET (column, ...) = (sub-select)
  abstract class Builder
    @@quote_character = '"'
    @@positional_arguments = false

    # :nodoc:
    def self.positional_arguments? : Bool
      @@positional_arguments
    end

    @@registers = {} of String => Builder.class

    def self.register(name : String, klass : Builder.class)
      @@registers[name] = klass
    end

    def self.fetch(name : String) : Builder.class
      @@registers[name]?.not_nil! "Unknown SQL driver: #{name}"
    end

    def self.fetch(name : Nil) : NoReturn
      name.not_nil! "Unknown SQL driver: #{name}"
    end

    getter? positional_arguments : Bool
    protected getter args : Array(ValueType)

    # :nodoc:
    def initialize(@args = Array(ValueType).new, @positional_arguments = true)
      @sql = ::String::Builder.new(capacity: 256)
    end

    # :nodoc:
    protected def as_sql : String
      @sql.to_s
    end

    def with(expressions : Tuple) : self
      @sql << "WITH "
      expressions.each_with_index do |(name, query), i|
        @sql << ", " unless i == 0
        quote name
        @sql << " AS ("
        to_sql query
        @sql << ')'
      end
      @sql << ' '
      self
    end

    def select(columns : Tuple) : self
      self.select(*columns)
    end

    def select : self
      self.select(:*)
    end

    def select(columns : Hash) : self
      @sql << "SELECT "

      to_sql_list(columns) do |column, name|
        to_sql_select(column)
        to_sql_select_as(name)
      end

      self
    end

    def select(columns : NamedTuple) : self
      @sql << "SELECT "

      to_sql_list(columns) do |column, name|
        quote column
        to_sql_select_as(name)
      end

      self
    end

    def select(*columns) : self
      @sql << "SELECT "
      to_sql_list(columns) { |column| to_sql_select(column) }
      self
    end

    protected def to_sql_select(column)
      case column
      in Column
        quote column.table_name
        @sql << '.'
        quote column.name
      in Table
        quote column.__table_name
        @sql << '.' << '*'
      in Symbol
        quote column
      in Expression, Over
        to_sql column
      end
    end

    def to_sql_select_as(name)
      return unless name
      @sql << " AS "
      quote name
    end

    def from(*tables) : self
      @sql << " FROM "
      to_sql_list(tables)
      self
    end

    def join(table : Table|Symbol) : self
      @sql << " JOIN "
      to_sql table
      self
    end

    def inner_join(table : Table|Symbol) : self
      @sql << " INNER JOIN "
      to_sql table
      self
    end

    {% for method in %w[left right full] %}
      def {{method.id}}_join(table : Table|Symbol) : self
        @sql << " {{method.upcase.id}} JOIN "
        to_sql table
        self
      end

      def {{method.id}}_outer_join(table : Table|Symbol) : self
        @sql << " {{method.upcase.id}} OUTER JOIN "
        to_sql table
        self
      end
    {% end %}

    def on(condition : Expression) : self
      @sql << " ON "
      to_sql condition
      self
    end

    def using(*join_columns : Symbol) : self
      @sql << " USING ("
      to_sql_list join_columns
      @sql << ')'
      self
    end

    def where(conditions) : self
      @sql << " WHERE "
      to_sql_where conditions
      self
    end

    def partition_by(*columns) : self
      @sql << "PARTITION BY "
      to_sql_list(columns) { |column| to_sql_select(column) }
      self
    end

    def group_by(*expressions) : self
      @sql << " GROUP BY "
      to_sql_list(expressions)
      self
    end

    def having(conditions) : self
      @sql << " HAVING "
      to_sql_where conditions
      self
    end

    def order_by(columns : Hash) : self
      @sql << " ORDER BY "

      to_sql_list(columns) do |expression, direction|
        to_sql expression
        to_sql_order_direction(direction)
      end

      self
    end

    def order_by(columns : NamedTuple) : self
      @sql << " ORDER BY "

      to_sql_list(columns) do |column, direction|
        quote column
        to_sql_order_direction(direction)
      end

      self
    end

    def order_by(*columns) : self
      @sql << " ORDER BY "
      to_sql_list(columns)
      self
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

    def limit(limit) : self
      @sql << " LIMIT " << limit.to_i
      self
    end

    def offset(offset) : self
      @sql << " OFFSET " << offset.to_i
      self
    end

    # def insert(query : NamedTuple) : {String, Array(ValueType)}
    #   @sql << "INSERT INTO "
    #   to_sql query[:into]

    #   if values = query[:values]?
    #     case values
    #     when NamedTuple, Hash
    #       to_sql_insert_columns(values)
    #       to_sql_insert_values(values)
    #     when Enumerable
    #       # TODO: BATCH INSERT
    #       raise NotImplementedError.new("batch insertion isn't implemented (yet)")
    #     else
    #       raise "Expected Hash or NamedTuple but got #{values.class.name}"
    #     end
    #   else
    #     @sql << " DEFAULT VALUES"
    #   end

    #   if on_conflict = query[:on_conflict]?
    #     to_sql_on_conflict(on_conflict)
    #   end

    #   if on_duplicate_key_update = query[:on_duplicate_key_update]?
    #     to_sql_on_duplicate_key_update(on_duplicate_key_update)
    #   end

    #   if returning = query[:returning]?
    #     to_sql_returning(returning)
    #   end

    #   {@sql.to_s, @args}
    # end

    # # Identical to `#insert` but with transparent support for cross database for
    # # `ON CONFLICT DO UPDATE SET` / `ON DUPLICATE KEY UPDATE`.
    # # def upsert(query : NamedTuple) : {String, Array(ValueType)}
    # #   TODO: upsert
    # # end

    # def update(query : NamedTuple) : {String, Array(ValueType)}
    #   @sql << "UPDATE "
    #   to_sql query[:update]

    #   @sql << " SET "
    #   to_sql_update_set(query[:set])

    #   if where = query[:where]?
    #     @sql << " WHERE "
    #     to_sql_where(where)
    #   end

    #   if returning = query[:returning]?
    #     to_sql_returning(returning)
    #   end

    #   {@sql.to_s, @args}
    # end

    def update(table : Table|Symbol) : self
      @sql << "UPDATE "
      to_sql table
      self
    end

    def set(columns : NamedTuple) : self
      @sql << " SET "

      to_sql_list(columns) do |column, value|
        quote column
        @sql << " = "
        to_sql_set_value(value)
      end

      self
    end

    def set(columns : Hash) : self
      @sql << " SET "

      to_sql_list(columns) do |column, value|
        case column
        in Column then quote column.name
        in Symbol then quote column
        end
        @sql << " = "
        to_sql_set_value(value)
      end

      self
    end

    protected def to_sql_set_value(value : Symbol) : Nil
      if value == :default
        @sql << "DEFAULT"
      else
        quote value
      end
    end

    protected def to_sql_set_value(value) : Nil
      to_sql value
    end

    def returning(*returning) : self
      @sql << " RETURNING "
      to_sql_list returning
      self
    end

    # def delete(query : NamedTuple) : {String, Array(ValueType)}
    #   @sql << "DELETE FROM "
    #   to_sql query[:from]

    #   if where = query[:where]?
    #     @sql << " WHERE "
    #     to_sql_where(where)
    #   end

    #   if returning = query[:returning]?
    #     to_sql_returning(returning)
    #   end

    #   {@sql.to_s, @args}
    # end

    # protected def to_sql_select(columns : Hash) : Nil
    #   columns.each_with_index do |(column, _as), i|
    #     @sql << ", " unless i == 0
    #     to_sql column
    #     @sql << ".*" if column.is_a?(Table)
    #     if _as
    #       @sql << " AS "
    #       quote _as
    #     end
    #   end
    # end

    # protected def to_sql_select(columns : Enumerable) : Nil
    #   columns.each_with_index do |column, i|
    #     @sql << ", " unless i == 0
    #     to_sql column
    #     @sql << ".*" if column.is_a?(Table)
    #   end
    # end

    # protected def to_sql_select(column : Table) : Nil
    #   to_sql column
    #   @sql << ".*"
    # end

    # protected def to_sql_select(columns) : Nil
    #   to_sql columns
    # end

    # protected def to_sql_insert_columns(values : Hash) : Nil
    #   @sql << " ("
    #   values.each_with_index do |(column, _), i|
    #     @sql << ", " unless i == 0
    #     to_sql_column_name(column)
    #   end
    #   @sql << ')'
    # end

    # protected def to_sql_insert_columns(values : NamedTuple) : Nil
    #   @sql << " ("
    #   values.each_with_index do |column, _, i|
    #     @sql << ", " unless i == 0
    #     to_sql column
    #   end
    #   @sql << ')'
    # end

    # protected def to_sql_insert_values(values : Hash) : Nil
    #   @sql << " VALUES ("
    #   values.each_with_index do |(_, value), i|
    #     @sql << ", " unless i == 0
    #     to_sql value
    #   end
    #   @sql << ')'
    # end

    # protected def to_sql_insert_values(values : NamedTuple) : Nil
    #   @sql << " VALUES ("
    #   values.each_with_index do |_, value, i|
    #     @sql << ", " unless i == 0
    #     to_sql value
    #   end
    #   @sql << ')'
    # end

    protected def to_sql_where(conditions : Enumerable) : Nil
      conditions.each_with_index do |condition, i|
        @sql << " AND " unless i == 0
        nested_expression { to_sql condition }
      end
    end

    protected def to_sql_where(conditions) : Nil
      to_sql conditions
    end

    # protected def to_sql_update_set(update : Hash) : Nil
    #   update.each_with_index do |(column, value), i|
    #     @sql << ", " unless i == 0
    #     to_sql_column_name column
    #     @sql << " = "
    #     to_sql value
    #   end
    # end

    # protected def to_sql_update_set(update : NamedTuple) : Nil
    #   update.each_with_index do |column_name, value, i|
    #     @sql << ", " unless i == 0
    #     quote(column_name)
    #     @sql << " = "
    #     to_sql value
    #   end
    # end

    protected def to_sql_list(list : Hash, &) : Nil
      list.each_with_index do |(key, value), i|
        @sql << ", " unless i == 0
        yield key, value
      end
    end

    protected def to_sql_list(list : NamedTuple, &) : Nil
      list.each_with_index do |key, value, i|
        @sql << ", " unless i == 0
        yield key, value
      end
    end

    protected def to_sql_list(list : Enumerable, &) : Nil
      list.each_with_index do |value, i|
        @sql << ", " unless i == 0
        yield value
      end
    end

    protected def to_sql_list(list : Enumerable) : Nil
      list.each_with_index do |value, i|
        @sql << ", " unless i == 0
        to_sql value
      end
    end

    # protected def to_sql_column_list(*columns : Column | Symbol | Wrap) : Nil
    #   columns.each_with_index do |column, i|
    #     @sql << ", " unless i == 0
    #     to_sql_column_name(column)
    #   end
    # end

    # protected def to_sql_column_name(column : Symbol | Wrap) : Nil
    #   quote column
    # end

    # protected def to_sql_column_name(column : Column) : Nil
    #   quote column.name
    # end

    protected def to_sql(expressions : Enumerable) : Nil
      to_sql_list(expressions)
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

        case rhs = binary.rhs
        in Array(ValueType)
          to_sql_list(rhs) { |arg| to_sql_statement_placeholder(arg) }
        in Builder
          to_sql rhs
        end
        @sql << ')'
      end
    end

    protected def to_sql(builder : Builder) : Nil
      @sql << builder.as_sql
      @args += builder.args if positional_arguments?
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

    protected def to_sql(over : Over) : Nil
      to_sql over.fn
      @sql << " OVER ("
      to_sql over.partition
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

    protected def to_sql(name : {Symbol, Symbol}) : Nil
      quote name[0]
      @sql << '.'
      quote name[1]
    end

    protected def to_sql(name : {Symbol, Symbol, Symbol}) : Nil
      quote name[0]
      @sql << '.'
      quote name[1]
      @sql << '.'
      quote name[2]
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
        @sql << @@quote_character
        @sql << name.to_s.gsub(@@quote_character, "\\#{@@quote_character}")
        @sql << @@quote_character
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
