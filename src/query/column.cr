require "./operators"

class SQL::Query
  # A column definition can have as much as 3 segments, for example:
  #
  # - `column`
  # - `table.column`
  # - `schema.table.column`
  struct Column
    include Operators

    getter name : {Symbol, Symbol?, Symbol?}
    getter? aliased : Symbol?

    def initialize(a : Symbol, b : Symbol? = nil, c : Symbol? = nil, *, as @aliased : Symbol? = nil)
      @name = {a, b, c}
    end

    def to_sql(builder : Builder::Generic) : Nil
      builder.quote @name[0]

      if b = @name[1]
        builder.sql << '.'
        builder.quote b
      end

      if c = @name[2]
        builder.sql << '.'
        builder.quote c
      end

      if aliased = @aliased
        builder.sql << " AS "
        builder.quote aliased
      end
    end
  end
end
