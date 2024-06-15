class SQL::Query
  module Helpers
    # Wraps a raw SQL expression. For example:
    #
    # ```
    # raw("concat_ws('formely( ' || column || ')')")
    # ```
    def raw(sql : String) : Raw
      Raw.new(sql)
    end

    # Wraps a column table with up to 3 segments (column, table.column or
    # schema.table.column). It can optionally take an alias.
    def column(a : Symbol, b : Symbol? = nil, c : Symbol? = nil, *, as aliased : Symbol? = nil) : Column
      Column.new(a, b, c, as: aliased)
    end

    # Custom binary operator. For example:
    #
    # ```
    # operator(table.col_a, "||", table.col_b)     # concat
    # operator(table.json, "->>", "path.to.value") # json extract value
    # ```
    #
    # Whenever possible function names will lead to a better reading code, but
    # sometimes a specific operator doesn't have a function counterpart.
    def operator(lhs : Expression, op : String, rhs : Expression) : BinaryOperation
      BinaryOperation.new(lhs, op, rhs)
    end
  end
end
