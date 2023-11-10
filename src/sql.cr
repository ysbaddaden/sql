require "uri"
require "uuid"
require "./dsl"
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
    dsl = DSL.new(@builder_class)
    builder = with dsl yield dsl
    {builder.as_sql, builder.args}
  end

  # def select(&) : {String, Array(ValueType)}
  #   @builder_class.new.select(with DSL.new yield)
  # end

  # def insert(&) : {String, Array(ValueType)}
  #   @builder_class.new.insert(with DSL.new yield)
  # end

  # def update(&) : {String, Array(ValueType)}
  #   @builder_class.new.update(with DSL.new yield)
  # end

  # def delete(&)
  #   @builder_class.new.delete(with DSL.new yield)
  # end
end
