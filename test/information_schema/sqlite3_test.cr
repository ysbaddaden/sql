require "minitest/autorun"
require "sqlite3"
require "../../src/information_schema"
require "../../src/query/builder/sqlite3"

class SQL::InformationSchema::SQLite3Test < Minitest::Test
  DATABASE_URL = "sqlite3:./sql_test.db"

  begin
    db = DB.open(DATABASE_URL)

    %w[binaries booleans floats integers strings].each do |table_name|
      db.exec %(DROP TABLE IF EXISTS "#{table_name}")
    end

    db.exec <<-SQL
      CREATE TABLE "binaries" ("b" BLOB)
    SQL

    db.exec <<-SQL
      CREATE TABLE "booleans" (
        "bolean" BOOLEAN,
        "bol" BOOL
      )
    SQL

    db.exec <<-SQL
      CREATE TABLE "floats" (
        "f32" FLOAT,
        "f64" DOUBLE
      )
    SQL

    db.exec <<-SQL
      CREATE TABLE "integers" (
        "i8" TINYINT,
        "i16" SMALLINT,
        "i32" INTEGER,
        "i64" BIGINT
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
  rescue ex
    STDERR.puts "#{ex.class.name}: #{ex.message}\n  #{ex.backtrace.join("\n  ")}"
    LibC.exit(1)
  end

  @schema : InformationSchema::SQLite3?

  private def schema
    @schema ||= InformationSchema::SQLite3.new(DATABASE_URL)
  end

  def test_tables
    assert_equal %w[binaries booleans floats integers strings], schema.tables.map(&.name)
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
    assert_equal [Float64, Float64], columns.map(&.to_crystal_type)
  end

  def test_integer_columns
    columns = schema.columns("integers")
    assert_equal %w[i8 i16 i32 i64], columns.map(&.name)
    assert_equal [Int8, Int16, Int32, Int64], columns.map(&.to_crystal_type)
  end

  def test_string_columns
    columns = schema.columns("strings")
    assert_equal %w[c16 vc vc50 txt], columns.map(&.name)
    assert_equal [16, nil, 50, nil], columns.map(&.character_maximum_length)
    assert_equal [64, nil, 200, nil], columns.map(&.character_octet_length)
    assert_equal [String, String, String, String], columns.map(&.to_crystal_type)
  end

  def test_time_columns
    skip "TODO: not yet implemented"
  end
end
