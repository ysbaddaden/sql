# SQL

A DSL to generate SQL queries for different database servers.

Goals:

- Simplify writing SQL queries, for example using a `NamedTuple` or `Hash`
  instead of ordering your args manually and counting your `?` in raw SQL
  strings;

- Avoid each database server quirks such as Postgres using `$i` for statement
  placeholders, or MySQL using backticks instead of double quotes for quoting
  column and table names;

- Feel like writing SQL in plain Crystal.

Non Goals:

- Executing queries.
- Becoming an ORM.

## Status

The SQL shard is in preliminary alpha. The basis shouldn't change much anymore,
but a lot still has to be evaluated in real life situations.

Supported database server flavors:

- MySQL / MariaDB
- PostgreSQL
- SQLite3

## Queries

You can write any query:

```crystal
require "sql"
require "sql/builder/posgres"

sql = SQL.new("postgres://")
sql.format { |q| q.select(:*).from(:users).where(q.column(:group_id) == 1) }
# => {%(SELECT * FROM "users" WHERE "group_id" = $1), [1]}
```

You can include `SQL::Helpers` into the current scope to simplify the access to
the `#column` method, along with other helpers (`#raw`, `#operator`).

```crystal
class UserRepo
  include SQL::Helpers

  def get(id)
    query, args = sql.format &.select(:id, :name).from(:users).where(column(:id) == id)
    db.query_one(query, args: args, as: {Int32, String})
  end
end
```

You can usually use a Symbol to refer to a table or column name, but there are
cases where we need an object, for example to build a WHERE or HAVING condition
and other cases. In these cases, we can define a SQL schema to target tables and
table columns in a much more expressive way.

### Schemas

You can define the schema of your database tables, so you can avoid the use of
the column helpers, as well as using aliases more easily. Work is underway to
have the schemas automatically generated from your database.

```crystal
class SQL
  module Schemas
    struct Users < Table
      table_name :users
      column :id
      column :group_id
      column :name
    end

    struct Groups < Table
      table_name :groups
      column :id
      column :name
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

db = DB.open("postgres://")
sql = SQL.new("postgres://")

# bring schemas and helpers into the current scope:
include SQL::Functions
include SQL::Helpers
include SQL::Schemas

query, args = sql.format do |q|
  q.select(Users.id, Users.name)
    .from(Users)
    .where(Users.group_id == 1)
end
# => {%(SELECT "users"."id", "users.name" FROM "users" WHERE "users"."group_id" = $1), [1]}

db.query_all(query, args: args, as: {Int32, String})
```

As you can see the WHERE condition is a regular Crystal comparison. Most
operators are supported. See `SQL::Operators` for the whole list of available
operators, and see the `#operator` helper to use any operator from your database
(albeit in a less expressive way).

Sub-queries:

```crystal
sql.format do |q|
  q.select(:*).from(Users).where(Users.group_id.in {
    q.select(:id).from(:groups).where(Groups.created_at < 1.month.ago)
  })
end
# => {%(SELECT "users"."id", FROM "users" WHERE "users"."group_id" IN (SELECT "groups"."id" FROM "groups" WHERE "groups".created_at < $1), [1.month.ago]}
```

Functions:

```crystal
sql.format do |q|
  q.select(:id, count(:*)).from(Users).group_by(Users.group_id).having(count(:*) > 2)
end
# => {%(SELECT "users"."id", count(*) FROM "users" GROUP BY "users"."group_id" HAVING count(*) > $1), [2]}
```

Aliases:

```crystal
sql.format do |q|
  u = Users[:u]
  q.select({u.id => :uid, u.name => nil, length(u.name) => :len}).from(u).where(u.group_id == 5)
end
# => {%(SELECT "u"."id" AS "uid", "u"."name", length("u"."name") AS "len" FROM "users" AS "u" WHERE "u"."group_id" == $1), [5]}
```

Lots more is possible! You can see lots of examples in the `test` folder or by
reading the main `src/builder.cr` file.

## Information Schema

TODO: missing docs (see `see/information_schema.cr`).

## License

Distributed under the Apache-2.0 license.

## Authors

- Julien Portalier

## Influences

- [diesel.rs](https://diesel.rs)
- [honeysql](https://github.com/seancorfield/honeysql)
