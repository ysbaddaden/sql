class SQL
  # TODO: WINDOW
  # TODO: SET column = DEFAULT
  # TODO: SET (column, ...) = (expression | DEFAULT)
  # TODO: SET (column, ...) = (sub-select)
  abstract class Builder
    @@quote_character = '"'
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

    # The IO object to generate the SQL string to.
    getter sql : String::Builder

    # The list of arguments to fill the prepared statement placeholders.
    getter args : Array(ValueType)

    # :nodoc:
    def initialize
      @sql = String::Builder.new(capacity: 256)
      @args = Array(ValueType).new
    end

    # Returns the generated SQL as a `String`. Can only be called once.
    def as_sql : String
      @sql.to_s
    end

    def with(expressions : Tuple) : self
      @sql << "WITH "
      expressions.each_with_index do |(name, query), i|
        @sql << ", " unless i == 0
        quote name
        @sql << " AS ("
        if query.is_a?(Proc)
          query.call
        else
          to_sql query
        end
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

    def select(**columns) : self
      self.select(columns)
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
      in Table, Table.class
        quote column.table_name
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

    def join(table : Table.class|Table|Symbol) : self
      @sql << " JOIN "
      to_sql table
      self
    end

    def inner_join(table : Table.class|Table|Symbol) : self
      @sql << " INNER JOIN "
      to_sql table
      self
    end

    {% for method in %w[left right full] %}
      def {{method.id}}_join(table : Table.class|Table|Symbol) : self
        @sql << " {{method.upcase.id}} JOIN "
        to_sql table
        self
      end

      def {{method.id}}_outer_join(table : Table.class|Table|Symbol) : self
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
      reset_nested_expression { to_sql_where conditions }
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
      reset_nested_expression { to_sql_where conditions }
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

    def insert_into(table, columns : Enumerable? = nil) : self
      @sql << "INSERT INTO "
      to_sql table

      if columns
        @sql << " ("
        to_sql_list(columns) { |column| to_sql_column_name(column) }
        @sql << ')'
      end

      self
    end

    def insert_into(table, columns : Enumerable? = nil, &) : self
      insert_into(table, columns)
      @sql << ' '
      yield
      self
    end

    def values(values : Hash) : self
      @sql << " ("
      to_sql_list(values) { |column, _| to_sql_column_name(column) }
      @sql << ')'

      @sql << " VALUES ("
      to_sql_list(values) { |_, value| to_sql value }
      @sql << ')'

      self
    end

    def values(values : NamedTuple) : self
      @sql << " ("
      to_sql_list(values) { |column_name, _| quote column_name }
      @sql << ')'

      @sql << " VALUES ("
      to_sql_list(values) { |_, value| to_sql value }
      @sql << ')'

      self
    end

    def values(**values) : self
      self.values(values)
    end

    def values(batch : Enumerable) : self
      @sql << " VALUES "

      to_sql_list(batch) do |values|
        @sql << '('
        to_sql_list(values)
        @sql << ')'
      end

      self
    end

    def default_values : self
      @sql << " DEFAULT VALUES"
      self
    end

    def on_duplicate_key_update(values : Hash) : self
      @sql << " ON DUPLICATE KEY UPDATE "
      to_sql_set(values)
      self
    end

    def on_duplicate_key_update(values : NamedTuple) : self
      @sql << " ON DUPLICATE KEY UPDATE "
      to_sql_set(values)
      self
    end

    def on_duplicate_key_update(columns : Enumerable) : Nil
      @sql << " ON DUPLICATE KEY UPDATE "

      to_sql_list(columns) do |column|
        to_sql_column_name column
        @sql << " = VALUES("
        to_sql_column_name column
        @sql << ')'
      end

      self
    end

    def on_duplicate_key_update(*columns) : self
      on_conflict_do_update(columns)
    end

    def on_conflict(column : Column | Symbol | Wrap | Raw | Nil = nil) : self
      @sql << " ON CONFLICT"

      if column
        @sql << " ("
        to_sql_column_name(column)
        @sql << ')'
      end

      self
    end

    def on_constraint(name : Symbol | Wrap | Raw) : self
      @sql << " ON CONSTRAINT "
      to_sql name
      self
    end

    def do_nothing : self
      @sql << " DO NOTHING"
      self
    end

    def do_update_set(values : Hash) : self
      @sql << " DO UPDATE SET "
      to_sql_set(values)
      self
    end

    def do_update_set(values : NamedTuple) : self
      @sql << " DO UPDATE SET "
      to_sql_set(values)
      self
    end

    def do_update_set(columns : Enumerable) : self
      @sql << " DO UPDATE SET "

      to_sql_list(columns) do |column|
        to_sql_column_name column
        @sql << " = EXCLUDED."
        to_sql_column_name column
      end

      self
    end

    def do_update_set(*columns) : self
      do_update_set(columns)
    end

    # Identical to `#insert` but with transparent support for cross database for
    # `ON CONFLICT DO UPDATE SET` / `ON DUPLICATE KEY UPDATE`.
    # def upsert(query : NamedTuple) : {String, Array(ValueType)}
    #   TODO: upsert
    # end

    def update(table : Table.class|Table|Symbol) : self
      @sql << "UPDATE "
      to_sql table
      self
    end

    def set(columns : NamedTuple) : self
      @sql << " SET "
      to_sql_set(columns)
      self
    end

    def set(columns : Hash) : self
      @sql << " SET "
      to_sql_set(columns)
      self
    end

    protected def to_sql_set(values : NamedTuple) : Nil
      to_sql_list(values) do |column, value|
        quote column
        @sql << " = "
        to_sql_set_value(value)
      end
    end

    protected def to_sql_set(values : Hash) : Nil
      to_sql_list(values) do |column, value|
        to_sql_column_name(column)
        @sql << " = "
        to_sql_set_value(value)
      end
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

    def delete_from(table) : self
      @sql << "DELETE FROM "
      to_sql table
      self
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

    protected def to_sql_column_name(column : Raw | Symbol | Wrap) : Nil
      to_sql column
    end

    protected def to_sql_column_name(column : Column) : Nil
      quote column.name
    end

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
        in Proc(Nil)
          rhs.call
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

    @[AlwaysInline]
    protected def to_sql(fn : Function) : Nil
      fn.to_sql(self)
    end

    protected def to_sql(over : Over) : Nil
      to_sql over.fn
      @sql << " OVER ("
      over.partition.call
      @sql << ')'
    end

    protected def to_sql(table : Table) : Nil
      quote table.table_name

      if _as = table.table_alias?
        @sql << " AS "
        quote _as
      end
    end

    protected def to_sql(table : Table.class) : Nil
      quote table.table_name
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

    protected def reset_nested_expression(&) : Nil
      original_nested = @nested
      @nested = false
      yield
      @nested = original_nested
    end
  end
end
