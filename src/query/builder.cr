require "../query"

module SQL
  class Query
    module Builder
      @@registers = {} of String => Generic.class

      def self.register(name : String, klass : Generic.class)
        @@registers[name] = klass
      end

      def self.fetch(name : String) : Generic.class
        @@registers[name]?.not_nil! "Unknown SQL driver: #{name}"
      end

      def self.fetch(name : Nil) : NoReturn
        name.not_nil! "Unknown SQL driver: #{name}"
      end
    end
  end
end

require "./builder/generic"
