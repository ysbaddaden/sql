require "./test_helper"

class SelectTest < Minitest::Test
  def test_with
    assert_format %(WITH "s" AS (SELECT *) SELECT * FROM "s"), do |q|
      q
        .with(:s, q.select(:*))
        .select(:*)
        .from(:s)
    end

    assert_format %(WITH "s" AS (SELECT *), "t" AS (SELECT *) SELECT * FROM "s", "t"), do |q|
      q
        .with(
          {:s, q.select(:*)},
          {:t, q.select(:*)},
        )
        .select(:*)
        .from(:s, :t)
    end
  end

  def test_select
    assert_format %(SELECT *) { _select(:*) }
    assert_format %(SELECT "user_id"), &.select(:user_id)
    assert_format %(SELECT USeRs.*) { _select(raw("USeRs.*")) }

    ## NOTE: I'm not convinced by the syntax `select: users` to `"users".*`
    assert_format %(SELECT "users".*) { _select(users) }
    assert_format %(SELECT "users".*, "count_all") { _select({users, :count_all}) }

    assert_format %(SELECT "users"."user_id", "users"."name") do |q|
      q.select(users.user_id, users.name)
    end

    assert_format %(SELECT "u"."name") { _select(users(:u).name) }

    assert_format %(SELECT "users"."name", length("users"."name") > $1), [10] do |q|
      q.select(users.name, length(users.name) > 10)
    end
  end

  def test_select_from
    assert_format %(SELECT * FROM "users"), &.select.from(:users)

    assert_format %(SELECT * FROM "users" AS "u") do |q|
      q.select.from(users(:u))
    end

    assert_format %(SELECT * FROM "groups", "users") do |q|
      q.select.from(groups, users)
    end

    assert_format %(SELECT * FROM "groups" AS "g", "users") do |q|
      q.select.from({groups(:g), users})
    end
  end

  def test_select_with_table_aliases
    assert_format %(SELECT "u"."user_id", "u"."name" FROM "users" AS "u") do |q|
      u = users(:u)
      q.select(u.user_id, u.name).from(u)
    end

    assert_format %(SELECT "a"."name", "b"."name" FROM "users" AS "a", "users" AS "b") do |q|
      a, b = users(:a), users(:b)
      q.select({a.name, b.name}).from(a, b)
    end

    assert_format %(SELECT "a"."name", "b"."name" AS "bn" FROM "users" AS "a", "users" AS "b") do |q|
      a, b = users(:a), users(:b)
      q.select({a.name => nil, b.name => :bn}).from(a, b)
    end

    assert_format %(SELECT length("users"."name") AS "len" FROM "users") do |q|
      q.select({length(users.name) => :len}).from(users)
    end
  end

  def test_select_over
    assert_format %(SELECT "name", lead("state") OVER (PARTITION BY "device", "name")) do
      _select(:name, lead(:state).over(partition_by(:device, :name)))
    end

    assert_format %(SELECT lag("state") OVER (PARTITION BY "device" ORDER BY "created_at")) do
      _select(lag(:state).over(partition_by(:device).order_by(:created_at)))
    end
  end

  def test_join
    assert_format %(SELECT "users".*, "groups"."name" AS "group_name" FROM "users" INNER JOIN "groups" ON "users"."group_id" = "groups"."group_id") do
      _select({users => nil, groups.name => :group_name})
        .from(users)
        .inner_join(groups).on(users.group_id == groups.group_id)
    end

    assert_format %(SELECT * FROM "users" JOIN "groups" ON "users"."group_id" = "groups"."group_id") do
      _select
        .from(users)
        .join(groups).on(users.group_id == groups.group_id)
    end

    assert_format %(SELECT * FROM "users" JOIN "groups" USING ("group_id")) do
      _select
        .from(users)
        .join(groups).using(:group_id)
    end

    assert_format %(SELECT * FROM "users" LEFT JOIN "groups" USING ("group_id")) do
      _select
        .from(users)
        .left_join(groups).using(:group_id)
    end

    assert_format %(SELECT * FROM "users" RIGHT JOIN "groups" USING ("group_id")) do
      _select
        .from(users)
        .right_join(groups).using(:group_id)
    end

    assert_format %(SELECT * FROM "users" FULL JOIN "groups" USING ("group_id")) do
      _select
        .from(users)
        .full_join(groups).using(:group_id)
    end
  end

  def test_join_retains_declaration_order
    assert_format %(SELECT * FROM "users" LEFT JOIN "users" AS "u" ON "u"."name" = "users"."name" INNER JOIN "groups" USING ("group_id")) do
      _select
        .from(users)
        .left_join(u = users(:u)).on(u.name == users.name)
        .inner_join(groups).using(:group_id)
    end
  end

  def test_where
    assert_format %(SELECT * FROM "users" WHERE ("users"."name" LIKE $1) AND ("users"."group_id" = $2)), ["john%", 2] do
      _select
        .from(users)
        .where(users.name.like("john%").and(users.group_id == 2))
    end

    assert_format %(SELECT * FROM "users" WHERE ("users"."name" LIKE $1) OR ("users"."group_id" = $2)), ["%doe%", 1] do
      _select
        .from(users)
        .where(users.name.like("%doe%").or(users.group_id == 1))
    end

    assert_format %(SELECT * FROM "users" WHERE ("users"."name" = $1) AND ("users"."group_id" >= $2)), ["john", 5] do
      _select
        .from(users)
        .where({users.name == "john", users.group_id >= 5})
    end
  end

  def test_where_in
    assert_format %(SELECT * FROM "users" WHERE "users"."group_id" IN ($1, $2, $3)), [4, 5, 6] do
      _select
        .from(users)
        .where(users.group_id.in({4, 5, 6}))
    end
  end

  def test_where_in_subquery
    assert_format %(SELECT * FROM "groups" WHERE "groups"."group_id" IN (SELECT "users"."group_id" FROM "users" WHERE "users"."user_id" < $1)), [123] do
      subquery = _select(users.group_id)
        .from(users)
        .where(users.user_id < 123)

      _select
        .from(groups)
        .where(groups.group_id.in(subquery))
    end

    assert_format %(SELECT * FROM "groups" WHERE ("groups"."group_id" <> $2) AND ("groups"."group_id" IN (SELECT "users"."group_id" FROM "users" WHERE "users"."user_id" < $1))), [123, 4] do
      subquery = _select(users.group_id)
        .from(users)
        .where(users.user_id < 123)

      _select
        .from(groups)
        .where((groups.group_id != 4).and(groups.group_id.in(subquery)))
    end
  end

  def test_group_by_and_having
    assert_format %(SELECT count(*) FROM "users" GROUP BY "users"."group_id") do
      _select(count(:*))
        .from(users)
        .group_by(users.group_id)
    end

    assert_format %(SELECT count(*) FROM "users" GROUP BY "users"."name", date_trunc($1, "users"."created_at")), ["year"] do
      _select(count(:*))
        .from(users)
        .group_by(users.name, date_trunc("year", users.created_at))
    end

    assert_format %(SELECT "users"."created_at", count(*) FROM "users" GROUP BY "users"."created_at" HAVING date_trunc($1, "users"."created_at") = $2), ["year", 2019] do
      _select(users.created_at, count(:*))
        .from(users)
        .group_by(users.created_at)
        .having(date_trunc("year", users.created_at) == 2019)
    end

    assert_format %(SELECT date_trunc($1, "users"."created_at") AS "date", count(*) AS "count_all" FROM "users" GROUP BY "date" HAVING "date" = $2), ["year", 2019] do
      _select({date_trunc("year", users.created_at) => :date, count(:*) => :count_all})
        .from(users)
        .group_by(:date)
        .having(column(:date) == 2019)
    end
  end

  def test_order_by
    assert_format %(SELECT * FROM "users" ORDER BY "created_at") do
      _select
        .from(users)
        .order_by(:created_at)
    end

    assert_format %(SELECT * FROM "users" ORDER BY "name", "created_at") do
      _select
        .from(users)
        .order_by(:name, :created_at)
    end

    assert_format %(SELECT * FROM "users" ORDER BY "users"."name", "users"."created_at") do
      _select
        .from(users)
        .order_by(users.name, users.created_at)
    end

    assert_format %(SELECT * FROM "users" ORDER BY "name", "created_at" DESC) do
      _select
        .from(users)
        .order_by({name: nil, created_at: :desc})
    end

    assert_format %(SELECT * FROM "users" ORDER BY "name", "created_at" ASC) do
      _select
        .from(users)
        .order_by({:name => nil, :created_at => :asc})
    end

    assert_format %(SELECT * FROM "users" ORDER BY "users"."name", "users"."created_at" DESC) do
      _select
        .from(users)
        .order_by({users.name => nil, users.created_at => :desc})
    end

    assert_format %(SELECT * FROM "users" ORDER BY "users"."name" NULLS LAST, "users"."created_at" DESC) do
      _select
        .from(users)
        .order_by({users.name => {nil, {nulls: :last}}, users.created_at => :desc})
    end

    assert_format %(SELECT * FROM "users" ORDER BY "users"."name", "users"."created_at" ASC NULLS FIRST) do
      _select
        .from(users)
        .order_by({users.name => nil, users.created_at => {:asc, {nulls: :first}}})
    end
  end

  def test_limit_and_offset
    assert_format %(SELECT * FROM "users" LIMIT 100) do
      _select.from(users).limit(100)
    end

    assert_format %(SELECT * FROM "users" LIMIT 2 OFFSET 4) do
      _select.from(users).limit(2).offset(4)
    end
  end
end
