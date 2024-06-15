require "./column"
require "./expression"
require "./helpers"
require "./table"
require "./raw"

class SQL::Query
  struct DSL
    include Helpers
    include Functions

    # :nodoc:
    def initialize(@__sql_builder : Builder::Generic)
    end

    # Start a WITH expression.
    def with(name : Symbol, &subquery : ->) : Builder::Generic
      self.with(name, subquery)
    end

    # Start a WITH expression.
    def with(name : Symbol, subquery : ->) : Builder::Generic
      @__sql_builder.with({ {name, subquery} })
    end

    # Start a WITH expression.
    def with(*expressions : Tuple) : Builder::Generic
      @__sql_builder.with(expressions)
    end

    # Start a SELECT query.
    def select(*columns) : Builder::Generic
      @__sql_builder.select(*columns)
    end

    # Start an INSERT query.
    def insert_into(table, columns = nil) : Builder::Generic
      @__sql_builder.insert_into(table, columns)
    end

    def insert_into(table, columns = nil, &) : Builder::Generic
      @__sql_builder.insert_into(table, columns) { yield }
    end

    # Start an UPDATE query.
    def update(table) : Builder::Generic
      @__sql_builder.update(table)
    end

    # Start a DELETE query.
    def delete_from(table) : Builder::Generic
      @__sql_builder.delete_from(table)
    end

    def partition_by(*columns) : Builder::Generic
      @__sql_builder.partition_by(*columns)
    end
  end
end
