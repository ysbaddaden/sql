require "db/serializable"

module SQL
  abstract class InformationSchema
    struct Table
      include DB::Serializable
      include DB::Serializable::NonStrict

      getter table_catalog : String
      getter table_schema : String
      getter table_name : String
      getter table_type : String?

      def initialize(@table_catalog, @table_schema, @table_name, @table_type)
      end

      def catalog : String
        @table_catalog
      end

      def schema : String
        @table_schema
      end

      def name : String
        @table_name
      end

      def type : String?
        @table_type
      end
    end
  end
end
