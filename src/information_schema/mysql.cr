require "../information_schema"
require "../sql"

class SQL
  class InformationSchema::MySQL < InformationSchema
    include Helpers

    def tables : Array(InformationSchema::Table)
      sql, args = @sql.format do |q|
        q.select(:table_catalog, :table_schema, :table_name, :table_type)
          .from({:information_schema, :tables})
          .where((column(:table_schema) == database_name).and(column(:table_name) != "schema_migrations"))
          .order_by(:table_name)
      end
      @db.query_all(sql, args: args, as: InformationSchema::Table)
    end

    def columns(table_name : String) : Array(InformationSchema::Column)
      # columns are UPPERCASE in MySQL and DB::Serializable is case-sensitive
      # so we must specify the list of columns for them to be properly mapped
      columns = {
        :table_catalog,
        :table_schema,
        :table_name,
        :column_name,
        :ordinal_position,
        :column_default,
        :is_nullable,
        :data_type,
        :character_maximum_length,
        :character_octet_length,
        :numeric_precision,
        :numeric_scale,
        :datetime_precision,
        :character_set_name,
        :collation_name,
        :column_type,
      }
      sql, args = @sql.format do |q|
        q.select(columns)
          .from({:information_schema, :columns})
          .where((column(:table_schema) == database_name).and(column(:table_name) == table_name))
          .order_by(:ordinal_position)
      end
      @db.query_all(sql, args: args, as: InformationSchema::Column)
    end
  end
end
