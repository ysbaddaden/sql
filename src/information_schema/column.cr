require "db/serializable"

class SQL
  abstract class InformationSchema
    struct Column
      include DB::Serializable
      include DB::Serializable::NonStrict

      property table_catalog : String
      property table_schema : String
      property table_name : String
      property column_name : String
      property ordinal_position : Int32 | Int64
      property column_default : String?
      property is_nullable : String
      property data_type : String
      property character_maximum_length : Int32 | Int64 | Nil
      property character_octet_length : Int32 | Int64 | Nil
      property numeric_precision : Int32 | Int64 | Nil
      property numeric_precision_radix : Int32?
      property numeric_scale : Int32 | Int64 | Nil
      property datetime_precision : Int32 | Int64 | Nil
      # property interval_type : String?
      # property interval_precision : Int32?
      # property character_set_catalog : String?
      # property character_set_schema : String?
      property character_set_name : String?
      # property collation_catalog : String?
      # property collation_schema : String?
      property collation_name : String?
      # property domain_catalog : String?
      # property domain_schema : String?
      # property domain_name : String?
      # property udt_catalog : String?
      # property udt_schema : String?
      # property udt_name : String?
      # property scope_catalog : String?
      # property scope_schema : String?
      # property scope_name : String?
      # property maximum_cardinality : Int32?
      # property dtd_identifier : String
      # property is_self_referencing : String
      # property is_identity : String
      # property identity_generation : String?
      # property identity_start : String?
      # property identity_increment : String?
      # property identity_maximum : String?
      # property identity_minimum : String?
      # property identity_cycle : String?
      # property is_generated : String
      # property generation_expression : String?
      # property is_updatable : String

      # MySQL extension
      getter column_type : String?

      def initialize(
        @table_catalog,
        @table_schema,
        @table_name,
        @column_name,
        @ordinal_position,
        @column_default,
        @is_nullable,
        @data_type,
        @character_maximum_length = nil,
        @character_octet_length = nil,
        @numeric_precision = nil,
        @numeric_precision_radix = nil,
        @numeric_scale = nil,
        @datetime_precision = nil,
        @character_set_name = nil,
        @collation_name = nil,
        @column_type = nil
      )
      end

      def name : String
        @column_name
      end

      def nullable? : Bool
        equals?(@is_nullable, "YES")
      end

      # def self_referencing? : Bool
      #   equals?(@is_self_referencing, "YES")
      # end

      # def identity? : Bool
      #   equals?(@is_identity, "YES")
      # end

      # def identity_cycle? : Bool
      #   equals?(@identity_cycle, "YES")
      # end

      # def generated? : Bool
      #   equals?(@is_generated, "ALWAYS")
      # end

      # def updatable? : Bool
      #   equals?(@is_updatable, "YES")
      # end

      private def equals?(a : String, *others : String) : Bool
        others.any? do |b|
          a.compare(b, case_insensitive: true) == 0
        end
      end

      def to_crystal_type
        if equals?(@data_type, "int", "integer", "bigint", "tinyint", "smallint", "mediumint")
          case {@numeric_precision_radix, @numeric_precision}
          when {2, 8}, {nil, 3}
            Int8
          when {2, 16}, {nil, 5}
            Int16
          when {2, 24}, {nil, 7}
            Int32
          when {2, 32}, {nil, 10}
            Int32
          when {2, 64}, {nil, 19}
            Int64
          end
        elsif equals?(@data_type, "double", "double precision", "float", "real")
          case {@numeric_precision_radix, @numeric_precision}
          when {2, 24}, {nil, 12}
            Float32
          when {2, 53}, {nil, 22}
            Float64
          end
        elsif equals?(@data_type, "char", "character", "varchar", "character varying", "text", "tinytext", "mediumtext", "longtext")
          String
        elsif equals?(@data_type, "boolean")
          Bool
        elsif equals?(@data_type, "date", "datetime", "timestamp", "timestamp without time zone", "timestamp with time zone")
          Time
        elsif equals?(@data_type, "blob", "bytea", "tinyblob", "mediumblob", "longblob")
          Bytes
        end
      end
    end
  end
end
