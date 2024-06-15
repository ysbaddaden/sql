require "./test_helper"

class SQL::BuilderTest < Minitest::Test
  include SQL::Query::Functions
  include SQL::Query::Helpers
  include SQL::Schemas

  register_function :date_trunc
  register_function :very_expensive_function

  def test_with
    assert_format %(WITH "s" AS (SELECT *) SELECT * FROM "s") do |q|
      q
        .with(:s) { q.select(:*) }
        .select(:*)
        .from(:s)
    end

    assert_format %(WITH "s" AS (SELECT *), "t" AS (SELECT *) SELECT * FROM "s", "t") do |q|
      q
        .with(
          {:s, ->{ q.select(:*) }},
          {:t, ->{ q.select(:*) }},
        )
        .select(:*)
        .from(:s, :t)
    end

    assert_format %(WITH "w" AS (SELECT "key", very_expensive_function("val") AS "f" FROM "some_table") SELECT * FROM "w"."w1" JOIN "w"."w2" ON "w1"."f" = "w2"."f") do |q|
      q.with(:w) { q.select({:key => nil, very_expensive_function(:val) => :f}).from(:some_table) }
        .select(:*)
        .from(column(:w, :w1))
        .join(column(:w, :w2))
        .on(column(:w1, :f) == column(:w2, :f))
    end
  end

  def test_select
    assert_format %(SELECT *), &.select(:*)
    assert_format %(SELECT "user_id"), &.select(:user_id)
    assert_format %(SELECT USeRs.*) { |q| q.select(q.raw("USeRs.*")) }

    # NOTE: I'm not convinced by the syntax `select: users` to `"users".*`
    assert_format %(SELECT "users".*), &.select(Users)
    assert_format %(SELECT "users".*, "count_all"), &.select({Users, :count_all})

    assert_format %(SELECT "users"."user_id", "users"."name") do |q|
      q.select(Users.user_id, Users.name)
    end

    assert_format %(SELECT "u"."name"), &.select(Users[:u].name)

    assert_format %(SELECT "users"."name", length("users"."name") > $1), [10] do |q|
      q.select(Users.name, q.length(Users.name) > 10)
    end
  end

  def test_select_aliases
    assert_format %(SELECT "u"."user_id", "u"."name" FROM "users" AS "u") do |q|
      u = Users[:u]
      q.select(u.user_id, u.name).from(u)
    end

    assert_format %(SELECT "a"."name", "b"."name" FROM "users" AS "a", "users" AS "b") do |q|
      a, b = Users[:a], Users[:b]
      q.select({a.name, b.name}).from(a, b)
    end

    assert_format %(SELECT "a"."name", "b"."name" AS "bn" FROM "users" AS "a", "users" AS "b") do |q|
      a, b = Users[:a], Users[:b]
      q.select({a.name => nil, b.name => :bn}).from(a, b)
    end

    assert_format %(SELECT length("users"."name") AS "len" FROM "users") do |q|
      q.select({q.length(Users.name) => :len}).from(Users)
    end
  end

  def test_select_expressions
    assert_format %(SELECT "name", lead("state") OVER (PARTITION BY "device", "name")) do |q|
      q.select(:name, lead(:state).over { q.partition_by(:device, :name) })
    end

    assert_format %(SELECT lag("state") OVER (PARTITION BY "device" ORDER BY "created_at")) do |q|
      q.select(lag(:state).over { q.partition_by(:device).order_by(:created_at) })
    end
  end

  def test_from
    assert_format %(SELECT * FROM "users"), &.select.from(:users)

    assert_format %(SELECT * FROM "users" AS "u") do |q|
      q.select.from(Users[:u])
    end

    assert_format %(SELECT * FROM "groups", "users") do |q|
      q.select.from(Groups, Users)
    end

    assert_format %(SELECT * FROM "groups" AS "g", "users") do |q|
      q.select.from({Groups[:g], Users})
    end
  end

  def test_join
    assert_format %(SELECT "users".*, "groups"."name" AS "group_name" FROM "users" INNER JOIN "groups" ON "users"."group_id" = "groups"."group_id") do |q|
      q.select({Users => nil, Groups.name => :group_name})
        .from(Users)
        .inner_join(Groups).on(Users.group_id == Groups.group_id)
    end

    assert_format %(SELECT * FROM "users" JOIN "groups" ON "users"."group_id" = "groups"."group_id") do |q|
      q.select
        .from(Users)
        .join(Groups).on(Users.group_id == Groups.group_id)
    end

    assert_format %(SELECT * FROM "users" JOIN "groups" USING ("group_id")) do |q|
      q.select
        .from(Users)
        .join(Groups).using(:group_id)
    end

    assert_format %(SELECT * FROM "users" LEFT JOIN "groups" USING ("group_id")) do |q|
      q.select
        .from(Users)
        .left_join(Groups).using(:group_id)
    end

    assert_format %(SELECT * FROM "users" RIGHT JOIN "groups" USING ("group_id")) do |q|
      q.select
        .from(Users)
        .right_join(Groups).using(:group_id)
    end

    assert_format %(SELECT * FROM "users" FULL JOIN "groups" USING ("group_id")) do |q|
      q.select
        .from(Users)
        .full_join(Groups).using(:group_id)
    end

    assert_format %(SELECT * FROM "users" LEFT JOIN "users" AS "u" ON "u"."name" = "users"."name" INNER JOIN "groups" USING ("group_id")) do |q|
      q.select
        .from(Users)
        .left_join(u = Users[:u]).on(u.name == Users.name)
        .inner_join(Groups).using(:group_id)
    end
  end

  def test_where
    assert_format %(SELECT * FROM "users" WHERE ("users"."name" LIKE $1) AND ("users"."group_id" = $2)), ["john%", 2] do |q|
      q.select
        .from(Users)
        .where(Users.name.like("john%").and(Users.group_id == 2))
    end

    assert_format %(SELECT * FROM "users" WHERE ("users"."name" LIKE $1) OR ("users"."group_id" = $2)), ["%doe%", 1] do |q|
      q.select
        .from(Users)
        .where(Users.name.like("%doe%").or(Users.group_id == 1))
    end

    assert_format %(SELECT * FROM "users" WHERE ("users"."name" = $1) AND ("users"."group_id" >= $2)), ["john", 5] do |q|
      q.select
        .from(Users)
        .where({Users.name == "john", Users.group_id >= 5})
    end

    assert_format %(SELECT * FROM "users" WHERE "users"."group_id" IN ($1, $2, $3)), [4, 5, 6] do |q|
      q.select
        .from(Users)
        .where(Users.group_id.in({4, 5, 6}))
    end

    assert_format %(SELECT * FROM "groups" WHERE "groups"."group_id" IN (SELECT "users"."group_id" FROM "users" WHERE "users"."user_id" < $1)), [123] do |q|
      q.select
        .from(Groups)
        .where(Groups.group_id.in {
          q.select(Users.group_id)
            .from(Users)
            .where(Users.user_id < 123)
        })
    end

    assert_format %(SELECT * FROM "groups" WHERE ("groups"."group_id" <> $1) AND ("groups"."group_id" IN (SELECT "users"."group_id" FROM "users" WHERE "users"."user_id" < $2))), [4, 123] do |q|
      q.select
        .from(Groups)
        .where((Groups.group_id != 4).and(Groups.group_id.in {
          q.select(Users.group_id)
            .from(Users)
            .where(Users.user_id < 123)
        }))
    end

    # TODO: 'where column = (sub-select)'
  end

  def test_group_by
    assert_format %(SELECT count(*) FROM "users" GROUP BY "users"."group_id") do |q|
      q.select(q.count(:*))
        .from(Users)
        .group_by(Users.group_id)
    end

    assert_format %(SELECT count(*) FROM "users" GROUP BY "users"."name", date_trunc($1, "users"."created_at")), ["year"] do |q|
      q.select(q.count(:*))
        .from(Users)
        .group_by(Users.name, date_trunc("year", Users.created_at))
    end
  end

  def test_having
    assert_format %(SELECT "users"."created_at", count(*) FROM "users" GROUP BY "users"."created_at" HAVING date_trunc($1, "users"."created_at") = $2), ["year", 2019] do |q|
      q.select(Users.created_at, q.count(:*))
        .from(Users)
        .group_by(Users.created_at)
        .having(date_trunc("year", Users.created_at) == 2019)
    end

    assert_format %(SELECT date_trunc($1, "users"."created_at") AS "date", count(*) AS "count_all" FROM "users" GROUP BY "date" HAVING "date" = $2), ["year", 2019] do |q|
      q.select({date_trunc("year", Users.created_at) => :date, q.count(:*) => :count_all})
        .from(Users)
        .group_by(:date)
        .having(q.column(:date) == 2019)
    end
  end

  def test_order_by
    assert_format %(SELECT * FROM "users" ORDER BY "created_at") do |q|
      q.select
        .from(Users)
        .order_by(:created_at)
    end

    assert_format %(SELECT * FROM "users" ORDER BY "name", "created_at") do |q|
      q.select
        .from(Users)
        .order_by(:name, :created_at)
    end

    assert_format %(SELECT * FROM "users" ORDER BY "users"."name", "users"."created_at") do |q|
      q.select
        .from(Users)
        .order_by(Users.name, Users.created_at)
    end

    assert_format %(SELECT * FROM "users" ORDER BY "name", "created_at" DESC) do |q|
      q.select
        .from(Users)
        .order_by({name: nil, created_at: :desc})
    end

    assert_format %(SELECT * FROM "users" ORDER BY "name", "created_at" ASC) do |q|
      q.select
        .from(Users)
        .order_by({:name => nil, :created_at => :asc})
    end

    assert_format %(SELECT * FROM "users" ORDER BY "users"."name", "users"."created_at" DESC) do |q|
      q.select
        .from(Users)
        .order_by({Users.name => nil, Users.created_at => :desc})
    end

    assert_format %(SELECT * FROM "users" ORDER BY "users"."name" NULLS LAST, "users"."created_at" DESC) do |q|
      q.select
        .from(Users)
        .order_by({Users.name => {nil, {nulls: :last}}, Users.created_at => :desc})
    end

    assert_format %(SELECT * FROM "users" ORDER BY "users"."name", "users"."created_at" ASC NULLS FIRST) do |q|
      q.select
        .from(Users)
        .order_by({Users.name => nil, Users.created_at => {:asc, {nulls: :first}}})
    end
  end

  def test_limit
    assert_format %(SELECT * FROM "users" LIMIT 100) do |q|
      q.select.from(Users).limit(100)
    end
  end

  def test_offset
    assert_format %(SELECT * FROM "users" LIMIT 2 OFFSET 4) do |q|
      q.select.from(Users).limit(2).offset(4)
    end
  end

  def test_insert_into
    assert_format %(INSERT INTO "users"), &.insert_into(users)
    assert_format %(INSERT INTO "groups"), &.insert_into(:groups)
  end

  def test_default_values
    assert_format %(INSERT INTO "users" DEFAULT VALUES), &.insert_into(users).default_values
    assert_format %(INSERT INTO "groups" DEFAULT VALUES), &.insert_into(:groups).default_values
  end

  def test_values
    # named tuple
    assert_format %(INSERT INTO "users" ("name", "email", "created_at") VALUES ($1, $2, now())), ["John", "john.doe@example.org"] do |q|
      q.insert_into(users).values({
        name:       "John",
        email:      "john.doe@example.org",
        created_at: q.now,
      })
    end

    # hash
    assert_format %(INSERT INTO "users" ("name", "created_at", "email", "group_id") VALUES ($1, now(), $2, $3)), ["Jane", "jane.doe@example.org", 123] do |q|
      q.insert_into(users).values({
        :name       => "Jane",
        :created_at => q.now,
        :email      => "jane.doe@example.org",
        :group_id   => 123,
      })
    end

    created = Time.utc
    assert_format %(INSERT INTO "users" ("created_at", "name", "email") VALUES ($1, $2, $3)), [created, "Jane", "jane.doe@example.org"] do |q|
      q.insert_into(users).values({
        users.created_at => created,
        users.name       => "Jane",
        users.email      => "jane.doe@example.org",
      })
    end

    assert_format %(INSERT INTO "users" ("name", "email") VALUES ($1, $2)), ["Jane", "jane.doe@example.org"] do |q|
      q.insert_into(users).values({
        q.column(:name)  => "Jane",
        q.column(:email) => "jane.doe@example.org",
      })
    end

    # batched insertions
    assert_format %(INSERT INTO "distributors" ("did", "dname") VALUES ($1, $2), ($3, $4)), [5, "Gizmo Transglobal", 6, "Associated Computing, Inc"] do |q|
      q.insert_into(:distributors, {:did, :dname}).values({
        {5, "Gizmo Transglobal"},
        {6, "Associated Computing, Inc"},
      })
    end

    assert_format %(INSERT INTO "films" VALUES ($1, $2, $3, DEFAULT, $4, $5)), ["UA502", "Bananas", 105, "Comedy", "82 minutes"] do |q|
      q.insert_into(:films).values([
        ["UA502", "Bananas", 105, q.raw("DEFAULT"), "Comedy", "82 minutes"],
      ])
    end
  end

  def test_on_conflict
    assert_format %(INSERT INTO "distributors" ("did", "dname") VALUES ($1, $2) ON CONFLICT ("did") WHERE "is_active" DO NOTHING), [9, "Antwerp Design"] do |q|
      q.insert_into(:distributors)
        .values({did: 9, dname: "Antwerp Design"})
        .on_conflict(:did)
        .where(:is_active)
        .do_nothing
    end
  end

  def test_on_constraint
    assert_format %(INSERT INTO "distributors" ("did", "dname") VALUES ($1, $2) ON CONFLICT ON CONSTRAINT "distributors_pkey" DO NOTHING), [10, "Conrad International"] do |q|
      q.insert_into(:distributors)
        .values({did: 10, dname: "Conrad International"})
        .on_conflict
        .on_constraint(:distributors_pkey)
        .do_nothing
    end
  end

  def test_do_nothing
    assert_format %(INSERT INTO "distributors" ("did", "dname") VALUES ($1, $2) ON CONFLICT DO NOTHING), [7, "Redline GmbH"] do |q|
      q.insert_into(:distributors)
        .values({did: 7, dname: "Redline GmbH"})
        .on_conflict
        .do_nothing
    end
  end

  def test_do_update_set
    assert_format %(INSERT INTO "distributors" ("did", "dname") VALUES ($1, $2), ($3, $4) ON CONFLICT ("did") DO UPDATE SET "dname" = EXCLUDED."dname"), [5, "Gizmo Transglobal", 6, "Associated Computing, Inc"] do |q|
      q.insert_into(:distributors, {:did, :dname})
        .values([
          {5, "Gizmo Transglobal"},
          {6, "Associated Computing, Inc"},
        ])
        .on_conflict(:did)
        .do_update_set(:dname)
    end

    assert_format %(INSERT INTO "distributors" ("did", "dname") VALUES ($1, $2) ON CONFLICT ("did") DO UPDATE SET "dname" = EXCLUDED.dname || ' (formerly ' || distributors.dname || ')' WHERE "zipcode" <> $3), [8, "Anvil Distribution", "21201"] do |q|
      q.insert_into(:distributors)
        .values({did: 8, dname: "Anvil Distribution"})
        .on_conflict(:did)
        .do_update_set({dname: q.raw("EXCLUDED.dname || ' (formerly ' || distributors.dname || ')'")})
        .where(q.column(:zipcode) != "21201")
    end

    assert_format %(INSERT INTO "distributors" ("did", "dname") VALUES ($1, $2) ON CONFLICT ("did") DO UPDATE SET "dname" = concat_ws(EXCLUDED.dname, $3, "dname", $4) WHERE "zipcode" <> $5), [8, "Anvil Distribution", "(formely", ")", "21201"] do |q|
      q.insert_into(:distributors)
        .values({did: 8, dname: "Anvil Distribution"})
        .on_conflict(:did)
        .do_update_set({dname: q.concat_ws(q.raw("EXCLUDED.dname"), "(formely", :dname, ")")})
        .where(q.column(:zipcode) != "21201")
    end
  end

  def test_returning
    assert_format %(INSERT INTO "users" ("email") VALUES ($1) RETURNING *), ["jane.doe@example.org"] do |q|
      q.insert_into(users)
        .values({email: "jane.doe@example.org"})
        .returning(:*)
    end

    assert_format %(UPDATE "users" SET "email" = $1 RETURNING "id"), ["jane.doe@example.org"] do |q|
      q.update(Users)
        .set({email: "jane.doe@example.org"})
        .returning(:id)
    end

    assert_format %(DELETE FROM "users" RETURNING "id", "email") do |q|
      q.delete_from(:users).returning(:id, :email)
    end
  end

  def test_update
    assert_format %(UPDATE "sessions"), &.update(:sessions)
    assert_format %(UPDATE "users"), &.update(Users)
    assert_format %(UPDATE "users" AS "u"), &.update(Users[:u])
  end

  def test_set
    assert_format %(UPDATE "groups" SET "name" = $1), ["Wales"] do |q|
      q.update(:groups).set({name: "Wales"})
    end

    assert_format %(UPDATE "groups" SET "name" = DEFAULT) do |q|
      q.update(:groups).set({name: :default})
    end

    assert_format %(UPDATE "groups" SET "name" = $1, "updated_at" = now(), "counter" = DEFAULT), ["Leos"] do |q|
      q.update(Groups).set({
        :name       => "Leos",
        :updated_at => q.now,
        :counter    => :default,
      })
    end

    updated = Time.utc
    assert_format %(UPDATE "groups" SET "name" = $1, "updated_at" = $2), ["Bears", updated] do |q|
      q.update(Groups).set({
        Groups.name       => "Bears",
        Groups.updated_at => updated,
      })
    end

    # NOTE: we might want to remove the table name from the expression (counter = counter + 1), this is valid yet uncommon
    assert_format %(UPDATE "groups" SET "counter" = "groups"."counter" + $1 WHERE "groups"."group_id" = $2), [1, 123] do |q|
      q.update(Groups)
        .set({counter: Groups.counter + 1})
        .where(Groups.group_id == 123)
    end
  end

  def test_where
    assert_format %(UPDATE "groups" SET "name" = $1 WHERE "groups"."group_id" = $2), ["Wales", 123] do |q|
      q.update(Groups)
        .set({name: "Wales"})
        .where(Groups.group_id == 123)
    end

    assert_format %(UPDATE "groups" SET "name" = $1 WHERE ("groups"."group_id" = $2) AND ("groups"."counter" < $3)), ["Wales", 123, 2] do |q|
      q.update(Groups)
        .set({name: "Wales"})
        .where([Groups.group_id == 123, Groups.counter < 2])
    end
  end

  def test_delete_from
    assert_format %(DELETE FROM "groups"), &.delete_from(Groups)
    assert_format %(DELETE FROM "users"), &.delete_from(:users)

    assert_format %(DELETE FROM "groups" WHERE "groups"."group_id" = $1), [123] do |q|
      q.delete_from(Groups)
        .where(Groups.group_id == 123)
    end

    assert_format %(DELETE FROM "groups" WHERE ("groups"."group_id" = $1) AND ("groups"."counter" < $2)), [123, 2] do |q|
      q.delete_from(Groups).where([
        Groups.group_id == 123,
        Groups.counter < 2,
      ])
    end
  end

  def test_complex_queries
    assert_format %(WITH "upd" AS (UPDATE "employees" SET "sales_count" = "sales_count" + $1 WHERE "id" IN (SELECT "sales_person" FROM "accounts" WHERE "name" = $2) RETURNING *) INSERT INTO "employees_log" SELECT *, "current_timestamp" FROM "upd"), [1, "Acme Corporation"] do |q|
      q.with(:upd) {
        q.update(:employees)
          .set({sales_count: q.column(:sales_count) + 1})
          .where(q.column(:id).in {
            q.select(:sales_person).from(:accounts).where(q.column(:name) == "Acme Corporation")
          })
          .returning(:*)
      }.insert_into(:employees_log) { q.select(:*, :current_timestamp).from(:upd) }
    end
  end
end
