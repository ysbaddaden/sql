require "../information_schema"
require "../sql"

module SQL
  class InformationSchema::PostgreSQL < InformationSchema
    include Query::Helpers

    def tables : Array(InformationSchema::Table)
      sql, args = @query.format do |q|
        q.select(:table_catalog, :table_schema, :table_name, :table_type)
          .from(column(:information_schema, :tables))
          .where((column(:table_schema) == "public")
            .and(column(:table_catalog) == database_name)
            .and(column(:table_name) != "schema_migrations"))
          .order_by(:table_name)
      end
      @db.query_all(sql, args: args, as: InformationSchema::Table)
    end

    def columns(table_name : String) : Array(InformationSchema::Column)
      sql, args = @query.format do |q|
        q.select(:*)
          .from(column(:information_schema, :columns))
          .where((column(:table_schema) == "public")
            .and(column(:table_catalog) == database_name)
            .and(column(:table_name) == table_name))
          .order_by(:ordinal_position)
      end
      @db.query_all(sql, args: args, as: InformationSchema::Column)
    end
  end
end
