require "./column"
require "./expression"
require "./helpers"
require "./table"
require "./raw"
require "./schemas"
require "./wrap"

class SQL
  struct QueryDSL
    include Helpers
    include Functions

    # :nodoc:
    def initialize(@__sql_builder : SQL::Builder)
    end

    # Start a WITH expression.
    def with(name : Symbol, &subquery : ->) : Builder
      self.with(name, subquery)
    end

    # Start a WITH expression.
    def with(name : Symbol, subquery : ->) : Builder
      @__sql_builder.with({ {name, subquery} })
    end

    # Start a WITH expression.
    def with(*expressions : Tuple) : Builder
      @__sql_builder.with(expressions)
    end

    # Start a SELECT query.
    def select(*columns) : Builder
      @__sql_builder.select(*columns)
    end

    # Start an INSERT query.
    def insert_into(table, columns = nil) : Builder
      @__sql_builder.insert_into(table, columns)
    end

    def insert_into(table, columns = nil, &) : Builder
      @__sql_builder.insert_into(table, columns) { yield }
    end

    # Start an UPDATE query.
    def update(table) : Builder
      @__sql_builder.update(table)
    end

    # Start a DELETE query.
    def delete_from(table) : Builder
      @__sql_builder.delete_from(table)
    end

    def partition_by(*columns) : Builder
      @__sql_builder.partition_by(*columns)
    end
  end
end
