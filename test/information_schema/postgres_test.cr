require "minitest/autorun"
require "pg"
require "../../src/information_schema"
require "../../src/query/builder/postgresql"

class SQL::InformationSchema::PostgresTest < Minitest::Test
  DATABASE_URL = "postgres://postgres:secret@localhost/sql_test"

  begin
    db = DB.open(DATABASE_URL)

    %w[binaries booleans floats integers serials strings times].each do |table_name|
      db.exec %(DROP TABLE IF EXISTS "#{table_name}")
    end

    db.exec <<-SQL
      CREATE TABLE "binaries" ("b" BYTEA)
    SQL

    db.exec <<-SQL
      CREATE TABLE "booleans" (
        "bolean" BOOLEAN,
        "bol" BOOL
      )
    SQL

    db.exec <<-SQL
      CREATE TABLE "floats" (
        "f32" REAL,
        "f64" DOUBLE PRECISION
      )
    SQL

    db.exec <<-SQL
      CREATE TABLE "integers" (
        "i16" SMALLINT,
        "i32" INTEGER,
        "i64" BIGINT
      )
    SQL

    db.exec <<-SQL
      CREATE TABLE "serials" (
        "id16" SMALLSERIAL,
        "id32" SERIAL,
        "id64" BIGSERIAL
      )
    SQL

    db.exec <<-SQL
      CREATE TABLE "strings" (
        "c16" CHAR(16),
        "vc" VARCHAR,
        "vc50" VARCHAR(50),
        "txt" TEXT
      )
    SQL

    db.exec <<-SQL
      CREATE TABLE "times" (
        "d" DATE,
        "t" TIME,
        "ttz" TIME WITH TIME ZONE,
        "ts" TIMESTAMP,
        "tstz" TIMESTAMP WITH TIME ZONE
      )
    SQL
  rescue ex
    STDERR.puts "#{ex.class.name}: #{ex.message}\n  #{ex.backtrace.join("\n  ")}"
    LibC.exit(1)
  end

  @schema : InformationSchema::PostgreSQL?

  private def schema
    @schema ||= InformationSchema::PostgreSQL.new(DATABASE_URL)
  end

  def test_tables
    assert_equal %w[binaries booleans floats integers serials strings times], schema.tables.map(&.name)
  end

  def test_binary_columns
    columns = schema.columns("binaries")
    assert_equal %w[b], columns.map(&.name)
    assert_equal [Bytes], columns.map(&.to_crystal_type)
  end

  def test_boolean_columns
    columns = schema.columns("booleans")
    assert_equal %w[bolean bol], columns.map(&.name)
    assert_equal [Bool, Bool], columns.map(&.to_crystal_type)
  end

  def test_decimal_columns
    skip "TODO: not yet implemented"
  end

  def test_enum_columns
    skip "TODO: not yet implemented"
  end

  def test_float_columns
    columns = schema.columns("floats")
    assert_equal %w[f32 f64], columns.map(&.name)
    assert_equal [Float32, Float64], columns.map(&.to_crystal_type)
  end

  def test_integer_columns
    columns = schema.columns("integers")
    assert_equal %w[i16 i32 i64], columns.map(&.name)
    assert_equal [Int16, Int32, Int64], columns.map(&.to_crystal_type)
  end

  def test_serial_columns
    columns = schema.columns("serials")
    assert_equal %w[id16 id32 id64], columns.map(&.name)
    assert_equal [Int16, Int32, Int64], columns.map(&.to_crystal_type)
  end

  def test_string_columns
    columns = schema.columns("strings")
    assert_equal %w[c16 vc vc50 txt], columns.map(&.name)
    assert_equal [16, nil, 50, nil], columns.map(&.character_maximum_length)
    assert_equal [64, 1024 * 1024 * 1024, 200, 1024 * 1024 * 1024], columns.map(&.character_octet_length)
    assert_equal [String, String, String, String], columns.map(&.to_crystal_type)
  end

  def test_time_columns
    columns = schema.columns("times")
    assert_equal %w[d t ttz ts tstz], columns.map(&.name)
    assert_equal [Time, nil, nil, Time, Time], columns.map(&.to_crystal_type)
  end

  def test_generate_table_schemas
    skip "write test"
    schema.generate_table_schemas(STDOUT)
  end
end
