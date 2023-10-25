require "./column"
require "./expression"
require "./table"
require "./raw"
require "./schemas"

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

    def raw(sql : String) : Raw
      Raw.new(sql)
    end
  end
end
