require "uri"
require "uuid"
require "./query_dsl"
require "./builder"

class SQL
  {% begin %}
    # NOTE: workaround for 'can't use Number, Int or Float in unions yet'
    {% number_types = Number.all_subclasses.reject { |t| {Float, Int}.includes?(t) } %}
    alias ValueType = {{ number_types.join(" | ").id }} | Bool | Time | UUID | String | Bytes | Nil
  {% end %}

  def self.new(uri : String) : self
    new URI.parse(uri)
  end

  def self.new(uri : URI) : self
    new Builder.fetch(uri.scheme)
  end

  def initialize(@builder_class : Builder.class)
  end

  def format(&) : {String, Array(ValueType)}
    dsl = QueryDSL.new(@builder_class.new)
    builder = yield dsl
    {builder.as_sql, builder.args}
  end
end
