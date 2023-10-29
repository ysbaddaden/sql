# SQL

A DSL to generate SQL queries for different database servers.

## Goals

- simplify writing your queries, for example using a `NamedTuple` or `Hash`
  instead of ordering your args manually and counting your `?` in raw SQL
  strings;

- avoid each database server quirks such as Postgres using `$i` for statement
  placeholders, or MySQL using backticks instead of double quotes for quoting
  column and table names;

- reduce SQL extension discrepencies between database servers, such as `ON
  CONFLIT DO` (Postgres, SQLite3) versus `ON DUPLICATE KEY` (MySQL).

### Non Goals

- becoming an ORM

## Status

The SQL shard is in preliminary alpha. The basis shouldn't change much, but a
lot is still needed.

## Examples

For now, you must define your database schema manually. Later, it should be
generated automatically from your database schema (e.g. once after running
migrations).

```crystal
class SQL
  module Schemas
    struct Users < Table
      def initialize(@__table_as = nil)
        @__table_name = :users
      end

      {% for col in %i[id group_id name] %}
        def {{col.id}} : Column
          Column.new(self, {{col}})
        end
      {% end %}
    end

    struct Groups < Table
      def initialize(@__table_as = nil)
        @__table_name = :groups
      end

      {% for col in %i[id name] %}
        def {{col.id}} : Column
          Column.new(self, {{col}})
        end
      {% end %}
    end

    def users(as name : Symbol? = nil)
      Users.new(name)
    end

    def groups(as name : Symbol? = nil)
      Groups.new(name)
    end
  end
end
```

Then you can:

```crystal
require "db"
require "sql"
require "sql/builder/postgres"
require "./schemas"

sql = SQL.new("postgres://")
query = sql.select do
  {
    select: {users.id, users.name},
    from: users,
    where: users.group_id == 1
  }
end
# => {%(SELECT "users"."id", "users.name" FROM "users" WHERE "users"."group_id" = ?), [1]}

db = DB.open("postgres://")
db.query_all(*query)
```

You can see has many examples of what's possible in the `test` folder (currently
being written) or by reading the main `src/builder.cr` file.

## License

Distributed under the Apache-2.0 license.

## Authors

- Julien Portalier
