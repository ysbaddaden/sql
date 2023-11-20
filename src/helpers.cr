class SQL
  module Helpers
    # Wraps a raw SQL expression. For example:
    #
    # ```
    # raw("concat_ws('formely( ' || column || ')')")
    # ```
    def raw(sql : String) : Raw
      Raw.new(sql)
    end

    # Wraps a column table. This can be used to refer to a column alias for
    # example.
    def column(name : Symbol) : Wrap
      Wrap.new(name)
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
