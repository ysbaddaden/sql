require "./expression"

class SQL
  struct Where
    macro method_missing(call)
      {% if call.named_args %}
        {% raise "BUG: unexpected named arguments" %}
      {% elsif call.args.empty? %}
        Column.new({{call.name.id.symbolize}})
      {% else %}
        Function.new({{call.name.id.symbolize}}, [{{call.args.splat}}] of Expression | Symbol)
      {% end %}
    end
  end
end
