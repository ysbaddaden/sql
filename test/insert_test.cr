require "./test_helper"

class InsertTest < Minitest::Test
  def test_into_with_default_values
    assert_query(%(INSERT INTO "users" DEFAULT VALUES), sql.insert do
      {into: users}
    end)
    assert_query(%(INSERT INTO "groups" DEFAULT VALUES), sql.insert do
      {into: groups}
    end)
  end

  def test_values_as_named_tuple
    assert_query(%(INSERT INTO "users" ("name", "email", "created_at") VALUES ($1, $2, now())), ["John", "john.doe@example.org"], sql.insert do
      {
        into:   users,
        values: {
          name:       "John",
          email:      "john.doe@example.org",
          created_at: now,
        },
      }
    end)
  end

  def test_values_as_hash
    assert_query(%(INSERT INTO "users" ("name", "created_at", "email", "group_id") VALUES ($1, now(), $2, $3)), ["Jane", "jane.doe@example.org", 123], sql.insert do
      {
        into:   users,
        values: {
          :name       => "Jane",
          :created_at => now,
          :email      => "jane.doe@example.org",
          :group_id   => 123,
        },
      }
    end)

    created = Time.utc
    assert_query(%(INSERT INTO "users" ("created_at", "name", "email") VALUES ($1, $2, $3)), [created, "Jane", "jane.doe@example.org"], sql.insert do
      {
        into:   users,
        values: {
          users.created_at => created,
          users.name       => "Jane",
          users.email      => "jane.doe@example.org",
        },
      }
    end)
  end

  def test_returning
    assert_query(%(INSERT INTO "users" ("email") VALUES ($1) RETURNING *), ["jane.doe@example.org"], sql.insert do
      {
        into:      users,
        values:    {email: "jane.doe@example.org"},
        returning: :*,
      }
    end)

    assert_query(%(INSERT INTO "users" ("email") VALUES ($1) RETURNING "id"), ["jane.doe@example.org"], sql.insert do
      {
        into:      users,
        values:    {email: "jane.doe@example.org"},
        returning: :id,
      }
    end)

    assert_query(%(INSERT INTO "users" ("email") VALUES ($1) RETURNING "id", "email"), ["jane.doe@example.org"], sql.insert do
      {
        into:      users,
        values:    {email: "jane.doe@example.org"},
        returning: {:id, :email},
      }
    end)
  end
end
