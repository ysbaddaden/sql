require "./column"
require "./expression"
require "./table"
require "./raw"
require "./schemas"
require "./wrap"

class SQL
  struct DSL
    include Schemas

    macro method_missing(call)
      {% raise "SQL functions can't receive named args" if call.named_args %}
      Function.new({{call.name.id.symbolize}}, [{{call.args.splat}}] of Expression)
    end

    # TODO: write methods for the most common SQL functions: COUNT, SUM, AVG, MIN, MAX, CONCAT, LENGTH, ...

    def now : Function
      Function.new(:now)
    end

    # Wraps a raw SQL expression.
    def raw(sql : String) : Raw
      Raw.new(sql)
    end

    # Wraps a column table. This is useful for refer to a column alias.
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
