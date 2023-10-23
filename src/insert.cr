class SQL
  class Insert
    @sql : SQL
    getter table_name : Symbol
    getter? default_values : Bool
    getter? on_conflict_ignore : Bool
    getter? on_conflict_update : Hash(Symbol, ValueType) | Enumerable(Symbol) | Nil

    def initialize(@sql, @table_name)
      @values = Array(Hash(Symbol, ValueType)).new
      @default_values = false
      @on_conflict_ignore = false
    end

    def values(default : Symbol) : self
      raise "SQL error: expected :default or NamedTuple but got #{default.inspect}" unless default == :default
      @default_values = true
      self
    end

    def values(values : NamedTuple) : self
      @values << convert_to_hash(values)
      self
    end

    def on_conflict_do(action : Symbol) : self
      raise "SQL error: expected :ignore or :update but got #{action.inspect}" unless action == :ignore
      @on_conflict_ignore = true
      @on_conflict_update = nil
      self
    end

    def on_conflict_do(*, update : NamedTuple) : self
      @on_conflict_ignore = false
      @on_conflict_update = convert_to_hash(update)
      self
    end

    def on_conflict_do(*, update : Enumerable(Symbol)) : self
      @on_conflict_ignore = false
      @on_conflict_update = update
      self
    end

    def column_names : Set(Symbol)
      columns = Set(Symbol).new
      @values.each { |values| values.each_key { |column| columns << column } }
      columns
    end

    def values : Array(Hash(Symbol, ValueType))
      @values
    end

    @[AlwaysInline]
    def to_sql : {String, Array(ValueType)}
      @sql.to_sql(self)
    end

    private def convert_to_hash(values : NamedTuple)
      hsh = Hash(Symbol, ValueType).new
      values.each { |column, value| hsh[column] = value }
      hsh
    end
  end
end
