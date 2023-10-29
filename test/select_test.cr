require "./test_helper"

class SelectTest < Minitest::Test
  def test_from
    assert_query(%(SELECT * FROM "users"), sql.select do
      {from: users}
    end)

    assert_query(%(SELECT * FROM "users" AS "u"), sql.select do
      {from: users(:u)}
    end)

    assert_query(%(SELECT * FROM "users", "groups"), sql.select do
      {from: {users, groups}}
    end)

    assert_query(%(SELECT * FROM "groups" AS "g", "users"), sql.select do
      {from: {groups(:g), users}}
    end)
  end

  def test_select
    # NOTE: I'm not convinced by the syntax `select: users` to `"users".*`
    assert_query(%(SELECT "users".* FROM "users"), sql.select { {select: users, from: users} })
    assert_query(%(SELECT "users".* FROM "users"), sql.select { {select: {users}, from: users} })

    assert_query(%(SELECT "users"."user_id", "users"."name" FROM "users"), sql.select do
      {
        select: {users.user_id, users.name},
        from:   users,
      }
    end)

    assert_query(%(SELECT "u"."name" FROM "users" AS "u"), sql.select do
      {
        from:   u = users(:u),
        select: u.name,
      }
    end)

    assert_query(%(SELECT "users"."name", length("users"."name") > $1 FROM "users"), [10], sql.select do
      {
        from:   users,
        select: {users.name, length(users.name) > 10},
      }
    end)
  end

  def test_select_with_aliases
    assert_query(%(SELECT "a"."name", "b"."name" FROM "users" AS "a", "users" AS "b"), sql.select do
      a, b = users(:a), users(:b)
      {
        from:   {a, b},
        select: {a.name, b.name},
      }
    end)

    assert_query(%(SELECT "a"."name", "b"."name" AS "bn" FROM "users" AS "a", "users" AS "b"), sql.select do
      a, b = users(:a), users(:b)
      {
        from:   {a, b},
        select: {a.name => nil, b.name => :bn},
      }
    end)

    assert_query(%(SELECT length("users"."name") AS "len" FROM "users"), sql.select do
      {
        select: {length(users.name) => :len},
        from:   users,
      }
    end)
  end

  def test_join
    assert_query(%(SELECT "users".*, "groups"."name" AS "group_name" FROM "users" INNER JOIN "groups" ON "users"."group_id" = "groups"."group_id"), sql.select do
      {
        select: {users => nil, groups.name => :group_name},
        from:   users,
        join:   {:inner, groups, {on: users.group_id == groups.group_id}},
      }
    end)

    assert_query(%(SELECT * FROM "users" INNER JOIN "groups" ON "users"."group_id" = "groups"."group_id"), sql.select do
      {
        from: users,
        join: {groups, {on: users.group_id == groups.group_id}},
      }
    end)

    assert_query(%(SELECT * FROM "users" INNER JOIN "groups" USING ("group_id")), sql.select do
      {
        from: users,
        join: {groups, {using: :group_id}},
      }
    end)

    assert_query(%(SELECT * FROM "users" LEFT JOIN "groups" USING ("group_id")), sql.select do
      {
        from: users,
        join: {:left, groups, {using: :group_id}},
      }
    end)

    assert_query(%(SELECT * FROM "users" RIGHT JOIN "groups" USING ("group_id")), sql.select do
      {
        from: users,
        join: {:right, groups, {using: :group_id}},
      }
    end)

    assert_query(%(SELECT * FROM "users" FULL JOIN "groups" USING ("group_id")), sql.select do
      {
        from: users,
        join: {:full, groups, {using: :group_id}},
      }
    end)
  end

  def test_join_fails_for_unknown_kind
    assert_raises do
      sql.select do
        {
          from: users,
          join: {:unknown, groups, {using: :group_id}},
        }
      end
    end
  end

  def test_join_requires_on_or_using_option
    assert_raises do
      sql.select do
        {
          from: users,
          join: {groups, {whatever: :wrong}},
        }
      end
    end
  end

  def test_join_retains_declaration_order
    assert_query(%(SELECT * FROM "users" LEFT JOIN "users" AS "u" ON "u"."name" = "users"."name" INNER JOIN "groups" ON "users"."group_id" = "groups"."group_id"), sql.select do
      {
        from: users,
        join: [
          {:left, u = users(:u), {on: u.name == users.name}},
          {:inner, groups, {on: users.group_id == groups.group_id}},
        ],
      }
    end)
  end

  def test_where
    assert_query(%(SELECT * FROM "users" WHERE ("users"."name" LIKE $1) AND ("users"."group_id" = $2)), ["john%", 2], sql.select do
      {
        from:  users,
        where: users.name.like("john%").and(users.group_id == 2),
      }
    end)

    assert_query(%(SELECT * FROM "users" WHERE ("users"."name" LIKE $1) OR ("users"."group_id" = $2)), ["%doe%", 1], sql.select do
      {
        from:  users,
        where: users.name.like("%doe%").or(users.group_id == 1),
      }
    end)

    assert_query(%(SELECT * FROM "users" WHERE ("users"."name" = $1) AND ("users"."group_id" >= $2)), ["john", 5], sql.select do
      {
        from:  users,
        where: {users.name == "john", users.group_id >= 5},
      }
    end)
  end

  def test_where_in
    assert_query(%(SELECT * FROM "users" WHERE "users"."group_id" IN ($1, $2, $3)), [4, 5, 6], sql.select do
      {
        from:  users,
        where: users.group_id.in({4, 5, 6}),
      }
    end)
  end

  def test_group_by_and_having
    assert_query(%(SELECT count(*) FROM "users" GROUP BY "users"."group_id"), sql.select do
      {
        select:   count(:*),
        from:     users,
        group_by: users.group_id,
      }
    end)

    assert_query(%(SELECT count(*) FROM "users" GROUP BY "users"."name", date_trunc($1, "users"."created_at")), ["year"], sql.select do
      {
        select:   count(:*),
        from:     users,
        group_by: {users.name, date_trunc("year", users.created_at)},
      }
    end)

    assert_query(%(SELECT "users"."created_at", count(*) FROM "users" GROUP BY "users"."created_at" HAVING date_trunc($1, "users"."created_at") = $2), ["year", 2019], sql.select do
      {
        select:   {users.created_at, count(:*)},
        from:     users,
        group_by: users.created_at,
        having:   date_trunc("year", users.created_at) == 2019,
      }
    end)

    assert_query(%(SELECT date_trunc($1, "users"."created_at") AS "date", count(*) AS "count_all" FROM "users" GROUP BY "date" HAVING "date" = $2), ["year", 2019], sql.select do
      {
        select:   {date_trunc("year", users.created_at) => :date, count(:*) => :count_all},
        from:     users,
        group_by: :date,
        having:   column(:date) == 2019,
      }
    end)
  end

  def test_order_by
    assert_query(%(SELECT * FROM "users" ORDER BY "created_at"), sql.select do
      {from: users, order_by: :created_at}
    end)

    assert_query(%(SELECT * FROM "users" ORDER BY "name", "created_at"), sql.select do
      {from: users, order_by: {:name, :created_at}}
    end)

    assert_query(%(SELECT * FROM "users" ORDER BY "users"."name", "users"."created_at"), sql.select do
      {from: users, order_by: {users.name, users.created_at}}
    end)

    assert_query(%(SELECT * FROM "users" ORDER BY "name", "created_at" DESC), sql.select do
      {from: users, order_by: {name: nil, created_at: :desc}}
    end)

    assert_query(%(SELECT * FROM "users" ORDER BY "name", "created_at" ASC), sql.select do
      {from: users, order_by: {:name => nil, :created_at => :asc}}
    end)

    assert_query(%(SELECT * FROM "users" ORDER BY "users"."name", "users"."created_at" DESC), sql.select do
      {from: users, order_by: {users.name => nil, users.created_at => :desc}}
    end)

    assert_query(%(SELECT * FROM "users" ORDER BY "users"."name" NULLS LAST, "users"."created_at" DESC), sql.select do
      {from: users, order_by: {users.name => {nil, {nulls: :last}}, users.created_at => :desc}}
    end)

    assert_query(%(SELECT * FROM "users" ORDER BY "users"."name", "users"."created_at" ASC NULLS FIRST), sql.select do
      {from: users, order_by: {users.name => nil, users.created_at => {:asc, {nulls: :first}}}}
    end)
  end

  def test_limit_and_offset
    assert_query(%(SELECT * FROM "users" LIMIT 100), sql.select do
      {from: users, limit: 100}
    end)

    assert_query(%(SELECT * FROM "users" LIMIT 2 OFFSET 4), sql.select do
      {from: users, limit: 2, offset: 4}
    end)
  end
end
