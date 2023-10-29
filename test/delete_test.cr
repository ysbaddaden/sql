require "./test_helper"

class DeleteTest < Minitest::Test
  def test_from
    assert_query(%(DELETE FROM "groups"), sql.delete do
      {from: groups}
    end)

    assert_query(%(DELETE FROM "users"), sql.delete do
      {from: users}
    end)
  end

  def test_where
    assert_query(%(DELETE FROM "groups" WHERE "groups"."group_id" = $1), [123], sql.delete do
      {
        from: groups,
        where: groups.group_id == 123
      }
    end)

    assert_query(%(DELETE FROM "groups" WHERE ("groups"."group_id" = $1) AND ("groups"."counter" < $2)), [123, 2], sql.delete do
      {
        from: groups,
        where: [groups.group_id == 123, groups.counter < 2],
      }
    end)
  end

  def test_returning
    assert_query(%(DELETE FROM "users" RETURNING *), sql.delete do
      {
        from:    users,
        returning: :*,
      }
    end)

    assert_query(%(DELETE FROM "users" RETURNING "id"), sql.delete do
      {
        from:    users,
        returning: :id,
      }
    end)

    assert_query(%(DELETE FROM "users" RETURNING "id", "email"), sql.delete do
      {
        from:    users,
        returning: {:id, :email},
      }
    end)
  end
end
