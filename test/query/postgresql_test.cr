require "../test_helper"

class SQL::Builder::PostgreSQLTest < Minitest::Test
  def sql_query
    SQL::Query.new("postgresql://")
  end

  def test_quotes
    assert_format %(SELECT "name" FROM "users"), &.select(:name).from(:users)

    assert_format %(SELECT "name" FROM "users" WHERE "created_at" < now()) do |q|
      q.select(:name)
        .from(:users)
        .where(q.column(:created_at) < q.now)
    end
  end

  def test_statement_placeholders
    assert_format %(SELECT "name" FROM "users" WHERE "id" = $1), [1] do |q|
      q.select(:name).from(:users).where(q.column(:id) == 1)
    end

    created = Time.utc
    assert_format %(INSERT INTO "users" VALUES ($1, $2)), ["Julien", created] do |q|
      q.insert_into(:users).values({
        {"Julien", created},
      })
    end
  end
end
