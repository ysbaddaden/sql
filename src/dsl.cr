require "./column"
require "./expression"
require "./table"
require "./raw"
require "./schemas"
require "./wrap"

class SQL
  struct DSL
    include Schemas

    @__sql_builder : SQL::Builder?

    # :nodoc:
    def initialize(@__sql_builder_class : SQL::Builder.class)
    end

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

    # Start a WITH expression.
    def with(name : Symbol, subquery : Builder) : Builder
      builder.with({ {name, subquery} })
    end

    # Start a WITH expression.
    def with(*expressions : Tuple) : Builder
      builder.with(expressions)
    end

    # Start a SELECT query.
    def _select(*columns) : Builder
      builder.select(*columns)
    end

    # Start a SELECT query.
    def select(*columns) : Builder
      builder.select(*columns)
    end

    # Start an INSERT query.
    def insert_into(table) : Builder
      builder.insert_into(table)
    end

    # Start an UPDATE query.
    def update(table) : Builder
      builder.update(table)
    end

    # Start a DELETE query.
    def delete_from(table) : Builder
      builder.delete_from(table)
    end

    def partition_by(*columns) : Builder
      builder.partition_by(*columns)
    end

    private def builder
      if (__sql_builder = @__sql_builder) && !__sql_builder.positional_arguments?
        # postgresql uses indexed statement placeholders, we share the same args
        # array between builders so sub-selects (evaluated before they're used)
        # will have a correct index (resulting in placeholders being out of
        # order in the query & args).
        #
        # FIXME: assumes that sub-queries will be injected into the main query!
        @__sql_builder_class.new(__sql_builder.@args, positional_arguments: false)
      else
        # other databases use ordered statement placedholders, and we can merely
        # concat the args between builds when needed to have ordered
        # placeholders/args
        @__sql_builder = @__sql_builder_class.new(
          positional_arguments: @__sql_builder_class.positional_arguments?)
      end
    end
  end
end
