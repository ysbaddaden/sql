require "uri"
require "uuid"
require "./query/dsl"
require "./query/builder"

module SQL
  class Query
    {% begin %}
      # NOTE: workaround for 'can't use Number, Int or Float in unions yet'
      {% number_types = Number.all_subclasses.reject { |t| {Float, Int}.includes?(t) } %}
      alias ValueType = {{ number_types.join(" | ").id }} | Bool | Time | UUID | String | Bytes | Nil
    {% end %}

    def self.new(database_uri : String) : self
      new URI.parse(database_uri)
    end

    def self.new(database_uri : URI) : self
      new Builder.fetch(database_uri.scheme)
    end

    def initialize(@builder_class : Builder::Generic.class)
    end

    def format(&) : {String, Array(ValueType)}
      dsl = DSL.new(@builder_class.new)
      builder = yield dsl
      {builder.as_sql, builder.args}
    end
  end
end
