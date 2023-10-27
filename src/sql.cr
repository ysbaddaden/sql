require "uri"
require "uuid"
require "./dsl"
require "./adapter"

class SQL
  {% begin %}
    # NOTE: workaround for 'can't use Number, Int or Float in unions yet'
    {% number_types = Number.all_subclasses.reject { |t| {Float, Int}.includes?(t) } %}
    alias ValueType = {{ number_types.join(" | ").id }} | Bool | Time | UUID | String | Bytes | Nil
  {% end %}

  protected getter adapter : SQL::Adapter.class

  def self.new(uri : String) : self
    new URI.parse(uri)
  end

  def self.new(uri : URI) : self
    adapter_name = uri.scheme.not_nil!
    new Adapter.for(adapter_name)
  end

  def initialize(@adapter)
  end

  def select(&) : {String, Array(ValueType)}
    @adapter.new.select(with DSL.new yield)
  end

  def insert(&) : {String, Array(ValueType)}
    @adapter.new.insert(with DSL.new yield)
  end

  def update(&) : {String, Array(ValueType)}
    @adapter.new.update(with DSL.new yield)
  end

  def delete(&)
    @adapter.new.delete(with DSL.new yield)
  end
end
