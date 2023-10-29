require "./test_helper"

class UpdateTest < Minitest::Test
  def test_set
    assert_query(%(UPDATE "groups" SET "name" = $1), ["Wales"], sql.update do
      {
        update: groups,
        set: {name: "Wales"},
      }
    end)

    assert_query(%(UPDATE "groups" SET "name" = $1, "updated_at" = now()), ["Leos"], sql.update do
      {
        update: groups,
        set: {:name => "Leos", :updated_at => now},
      }
    end)

    updated = Time.utc
    assert_query(%(UPDATE "groups" SET "name" = $1, "updated_at" = $2), ["Bears", updated], sql.update do
      {
        update: groups,
        set: {groups.name => "Bears", groups.updated_at => updated},
      }
    end)

    # TODO: we might want to remove the table name from the expression (counter = counter + 1), this is valid yet uncommon
    assert_query(%(UPDATE "groups" SET "counter" = "groups"."counter" + $1 WHERE "groups"."group_id" = $2), [1, 123], sql.update do
      {
        update: groups,
        set: {counter: groups.counter + 1},
        where: groups.group_id == 123
      }
    end)
  end

  def test_where
    assert_query(%(UPDATE "groups" SET "name" = $1 WHERE "groups"."group_id" = $2), ["Wales", 123], sql.update do
      {
        update: groups,
        set: {name: "Wales"},
        where: groups.group_id == 123
      }
    end)

    assert_query(%(UPDATE "groups" SET "name" = $1 WHERE ("groups"."group_id" = $2) AND ("groups"."counter" < $3)), ["Wales", 123, 2], sql.update do
      {
        update: groups,
        set: {name: "Wales"},
        where: [groups.group_id == 123, groups.counter < 2],
      }
    end)
  end

  def test_returning
    assert_query(%(UPDATE "users" SET "email" = $1 RETURNING *), ["jane.doe@example.org"], sql.update do
      {
        update:    users,
        set:       {email: "jane.doe@example.org"},
        returning: :*,
      }
    end)

    assert_query(%(UPDATE "users" SET "email" = $1 RETURNING "id"), ["jane.doe@example.org"], sql.update do
      {
        update:    users,
        set:       {email: "jane.doe@example.org"},
        returning: :id,
      }
    end)

    assert_query(%(UPDATE "users" SET "email" = $1 RETURNING "id", "email"), ["jane.doe@example.org"], sql.update do
      {
        update:    users,
        set:       {email: "jane.doe@example.org"},
        returning: {:id, :email},
      }
    end)
  end
end
