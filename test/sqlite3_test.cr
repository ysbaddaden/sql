require "./test_helper"

class SQLite3Test < Minitest::Test
  def sql
    SQL.new("sqlite3://")
  end

  def test_select
    skip "todo: write one big select query"
  end

  def test_on_conflict_do_nothing
    assert_query(%(INSERT INTO "groups" ("name") VALUES (?) ON CONFLICT DO NOTHING), ["Sparrows"], sql.insert do
      {
        into:        groups,
        values:      {name: "Sparrows"},
        on_conflict: :do_nothing,
      }
    end)

    assert_query(%(INSERT INTO "groups" ("name") VALUES (?) ON CONFLICT ("group_id") DO NOTHING), ["Sparrows"], sql.insert do
      {
        into:        groups,
        values:      {name: "Sparrows"},
        on_conflict: {groups.group_id, :do_nothing},
      }
    end)
  end

  def test_on_conflict_do_update_set
    assert_query(%(INSERT INTO "users" ("name", "email") VALUES (?, ?) ON CONFLICT ("email") DO UPDATE SET "name" = EXCLUDED."name"), ["John", "john.doe@example.org"], sql.insert do
      {
        into:        users,
        values:      {name: "John", email: "john.doe@example.org"},
        on_conflict: {:email, {do_update_set: {:name}}},
      }
    end)

    assert_query(%(INSERT INTO "users" ("name", "email") VALUES (?, ?) ON CONFLICT ("email") DO UPDATE SET "name" = EXCLUDED."name"), ["John", "john.doe@example.org"], sql.insert do
      {
        into:        users,
        values:      {name: "John", email: "john.doe@example.org"},
        on_conflict: {users.email, {do_update_set: :name}},
      }
    end)

    assert_query(%(INSERT INTO "users" ("name", "email") VALUES (?, ?) ON CONFLICT ("email") DO UPDATE SET "name" = ?), ["John", "john.doe@example.org", "John"], sql.insert do
      {
        into:        users,
        values:      {name: "John", email: "john.doe@example.org"},
        on_conflict: {users.email, {do_update_set: {name: "John"}}},
      }
    end)

    assert_query(%(INSERT INTO "users" ("email", "name") VALUES (?, ?) ON CONFLICT ("email") DO UPDATE SET "name" = ?), ["jane.doe@example.org", "jane", "John"], sql.insert do
      {
        into:        users,
        values:      {email: "jane.doe@example.org", name: "jane"},
        on_conflict: {users.email, {do_update_set: {users.name => "John"}}},
      }
    end)
  end

  def test_on_duplicate_key_update
    assert_raises do
      sql.insert do
        {
          into:                    users,
          values:                  {email: "john.doe@example.org"},
          on_duplicate_key_update: {:name},
        }
      end
    end
  end
end
