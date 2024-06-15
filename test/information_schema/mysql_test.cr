require "minitest/autorun"
require "mysql"
require "../../src/information_schema"
require "../../src/query/builder/mysql"

class SQL::InformationSchema::MySQLTest < Minitest::Test
  DATABASE_URL = "mysql://root:secret@localhost/sql_test"

  begin
    db = DB.open(DATABASE_URL)

    %w[binaries floats integers strings times].each do |table_name|
      db.exec %(DROP TABLE IF EXISTS `#{table_name}`)
    end

    db.exec <<-SQL
      CREATE TABLE `binaries` (
        `tb` TINYBLOB,
        `b` BLOB,
        `mb` MEDIUMBLOB,
        `lb` LONGBLOB
      ) DEFAULT CHARACTER SET utf8mb4
    SQL

    db.exec <<-SQL
      CREATE TABLE `floats` (
        `f32` FLOAT,
        `f64` DOUBLE
      ) DEFAULT CHARACTER SET utf8mb4
    SQL

    db.exec <<-SQL
      CREATE TABLE `integers` (
        `i8` TINYINT,
        `i16` SMALLINT,
        `i24` MEDIUMINT,
        `i32` INTEGER,
        `i64` BIGINT
      ) DEFAULT CHARACTER SET utf8mb4
    SQL

    db.exec <<-SQL
      CREATE TABLE `strings` (
        `c16` CHAR(16),
        `vc50` VARCHAR(50),
        `txt8` TINYTEXT,
        `txt` TEXT,
        `txt24` MEDIUMTEXT,
        `txt32` LONGTEXT
      ) DEFAULT CHARACTER SET utf8mb4
    SQL

    db.exec <<-SQL
      CREATE TABLE `times` (
        `d` DATE,
        `t` TIME,
        `dt` DATETIME,
        `ts` TIMESTAMP
      ) DEFAULT CHARACTER SET utf8mb4
    SQL
  rescue ex
    STDERR.puts "#{ex.class.name}: #{ex.message}\n  #{ex.backtrace.join("\n  ")}"
    LibC.exit(1)
  end

  @schema : InformationSchema::MySQL?

  private def schema
    @schema ||= InformationSchema::MySQL.new(DATABASE_URL)
  end

  def test_tables
    assert_equal %w[binaries floats integers strings times], schema.tables.map(&.name)
  end

  def test_binary_columns
    columns = schema.columns("binaries")
    assert_equal %w[tb b mb lb], columns.map(&.name)
    assert_equal [Bytes, Bytes, Bytes, Bytes], columns.map(&.to_crystal_type)
    assert_equal [255, 65535, 16777215, 4294967295], columns.map(&.character_maximum_length)
    assert_equal [255, 65535, 16777215, 4294967295], columns.map(&.character_octet_length)
  end

  def test_boolean_columns
    skip "MySQL doesn't have a boolean type"
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
    assert_equal %w[i8 i16 i24 i32 i64], columns.map(&.name)
    assert_equal [Int8, Int16, Int32, Int32, Int64], columns.map(&.to_crystal_type)
  end

  def test_string_columns
    columns = schema.columns("strings")
    assert_equal %w[c16 vc50 txt8 txt txt24 txt32], columns.map(&.name)
    assert_equal [16, 50, 255, 65535, 16777215, 4294967295], columns.map(&.character_maximum_length)
    assert_equal [64, 200, 255, 65535, 16777215, 4294967295], columns.map(&.character_octet_length)
    assert_equal [String, String, String, String, String, String], columns.map(&.to_crystal_type)
  end

  def test_time_columns
    columns = schema.columns("times")
    assert_equal %w[d t dt ts], columns.map(&.name)
    assert_equal [Time, nil, Time, Time], columns.map(&.to_crystal_type)
  end
end
