require "../information_schema"
require "../sql"

class SQL
  class InformationSchema::SQLite3 < InformationSchema
    def tables : Array(InformationSchema::Table)
      tables = [] of InformationSchema::Table

      sql, args = @sql.format do |q|
        q.select(:tbl_name)
          .from(:sqlite_master)
          .where(column(:type) == "table")
          .order_by(:tbl_name)
      end
      @db.query_each(sql, args: args) do |rs|
        tables << InformationSchema::Table.new("", "", rs.read(String), "BASE TABLE")
      end

      tables
    end

    def columns(table_name : String) : Array(InformationSchema::Column)
      columns = [] of InformationSchema::Column

      # TODO: use pragma_table_xinfo to list generated/hidden columns
      sql, args = @sql.format do |q|
        q.select(:name, :cid, :dflt_value, :notnull, :type)
          .from(pragma_table_info(table_name))
          .order_by(:cid)
      end
      @db.query_each(sql, args: args) do |rs|
        column = InformationSchema::Column.new(
          "",
          "",
          table_name,
          rs.read(String),
          rs.read(Int32),
          rs.read(String?),
          rs.read(Bool) ? "NO" : "YES", # notnull => is_nullable
          rs.read(String).downcase,
        )
        columns << normalize(column)
      end

      columns
    end

    # SQLite3 has a very flexible type system and accepts whatever as data-types
    # then uses affinities to determine the actual storage type. This is trying
    # to map the terms to what we could expect.
    def normalize(column : InformationSchema::Column) : InformationSchema::Column
      case column.data_type
      when "tinyint", "int1"
        column.data_type = "tinyint"
        column.numeric_precision_radix = 2
        column.numeric_precision = 8
      when "smallint", "int2"
        column.data_type = "smallint"
        column.numeric_precision_radix = 2
        column.numeric_precision = 16
      when "int", "integer", "int4"
        column.data_type = "integer"
        column.numeric_precision_radix = 2
        column.numeric_precision = 32
      when "bigint", "int8"
        column.data_type = "bigint"
        column.numeric_precision_radix = 2
        column.numeric_precision = 64
      when "float", "real", "double", "double precision"
        column.data_type = "double"
        column.numeric_precision_radix = 2
        column.numeric_precision = 53
      when /^char\((\d+)\)$/
        column.data_type = "char"
        column.character_maximum_length = $1.to_i32
        column.character_octet_length = $1.to_i32 * 4
      when /^varchar\((\d+)\)$/
        column.data_type = "varchar"
        column.character_maximum_length = $1.to_i32
        column.character_octet_length = $1.to_i32 * 4
      when "bool"
        column.data_type = "boolean"
        # column.numeric_precision_radix = 2
        # column.numeric_precision = 8
      end
      column
    end
  end
end
