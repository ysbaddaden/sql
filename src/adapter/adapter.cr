class SQL
  abstract struct Adapter
    QUOTE_CHARACTER = '"'

    @@adapter_classes = {} of String => Adapter.class

    def self.register(name : String, adapter_klass : Adapter.class) : Nil
      @@adapter_classes[name] = adapter_klass
    end

    def self.for(name : String) : Adapter.class
      @@adapter_classes[name]
    end

    def initialize
      @sql = String::Builder.new(capacity: 256)
      @args = [] of ValueType
    end

    def to_sql(q : Select) : {String, Array(ValueType)}
      @sql << "SELECT "
      q.columns.each_with_index do |column, i|
        @sql << ", " unless i == 0
        quote(column)
      end

      @sql << " FROM "
      quote(q.from.not_nil!)

      if condition = q.condition?
        @sql << " WHERE "
        to_sql(condition)
      end

      {@sql.to_s, @args}
    end

    def to_sql(q : Insert) : {String, Array(ValueType)}
      column_names = q.column_names

      @sql << "INSERT INTO "
      quote(q.table_name)

      @sql << " ("
      column_names.each_with_index do |column_name, i|
        @sql << ", " unless i == 0
        quote(column_name)
      end
      @sql << ')'

      if q.default_values?
        @sql << " DEFAULT VALUES "
      else
        @sql << " VALUES "
        q.values.each_with_index do |values, i|
          @sql << ", " unless i == 0
          @sql << '('
          column_names.each_with_index do |column_name, j|
            @sql << ", " unless j == 0
            prepared_statement_placeholder(values[column_name]?)
          end
          @sql << ')'
        end
      end

      if q.on_conflict_ignore?
        on_conflict_do_ignore_statement
      elsif update = q.on_conflict_update?
        on_conflict_do_update_statement(update)
      end

      {@sql.to_s, @args}
    end

    def to_sql(binary : BinaryOperation) : Nil
      @sql << '('
      to_sql(binary.lhs)
      @sql << ' '
      @sql << binary.operator
      @sql << ' '
      to_sql(binary.rhs)
      @sql << ')'
    end

    def to_sql(unary : UnaryOperation) : Nil
      @sql << '('
      to_sql(unary.expression)
      @sql << ' '
      @sql << unary.operator
      @sql << ')'
    end

    def to_sql(column : Column) : Nil
      quote(column.name)
    end

    def to_sql(fn : Function) : Nil
      @sql << fn.name
      @sql << '('
      fn.args.each_with_index do |expression, i|
        @sql << ", " unless i == 0
        to_sql(expression)
      end
      @sql << ')'
    end

    def to_sql(value : ValueType) : Nil
      prepared_statement_placeholder(value)
    end

    def to_sql(column_name : Symbol) : Nil
      quote(column_name)
    end

    protected def update_statement(update : Hash)
      update.each_with_index do |(column_name, value), i|
        @sql << ", " unless i == 0
        quote(column_name)
        @sql << " = "
        prepared_statement_placeholder(value)
      end
    end

    def on_conflict_do_ignore_statement : Nil
      @sql << " ON CONFLICT DO IGNORE"
    end

    def on_conflict_do_update_statement(update : Hash) : Nil
      @sql << " ON CONFLICT DO UPDATE SET "
      update_statement(update)
    end

    def on_conflict_do_update_statement(update : Enumerable(Symbol)) : Nil
      @sql << " ON CONFLICT DO UPDATE SET "

      update.each_with_index do |column_name, i|
        @sql << ", " unless i == 0
        quote(column_name)
        @sql << " = "
        @sql << "EXCLUDED."
        quote(column_name)
      end
    end

    def prepared_statement_placeholder(value : ValueType) : Nil
      @args << value
      @sql << '?'
    end

    def quote(column : Symbol)
      if column == :*
        @sql << '*'
      else
        # FIXME: properly quote (escape QUOTE_CHARACTER)
        @sql << QUOTE_CHARACTER << column << QUOTE_CHARACTER
      end
    end

    def quote(column : Tuple(Symbol, Symbol))
      quote(column[0])
      @sql << '.'
      quote(column[1])
    end
  end
end
