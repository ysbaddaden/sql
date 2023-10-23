require "db"
require "uri"
require "uuid"
require "./adapter/adapter"
require "./select"
require "./insert"

class SQL
  {% begin %}
    # NOTE: workaround for 'can't use Number, Int or Float in unions yet'
    {% number_types = Number.all_subclasses.reject { |t| {Float, Int}.includes?(t) } %}
    alias ValueType = {{ number_types.join(" | ").id }} | Bool | Time | UUID | String | Bytes | Nil
  {% end %}

  alias ColumnName = Symbol | {Symbol, Symbol}

  # protected getter db : DB::Database
  protected getter adapter : SQL::Adapter.class

  def self.new(uri : String) : self
    new URI.parse(uri)
  end

  def self.new(uri : URI) : self
    # new DB.open(uri), Adapter.for(uri.scheme.not_nil!)
    new Adapter.for(uri.scheme.not_nil!)
  end

  # def initialize(@db, @adapter)
  # end

  def initialize(@adapter)
  end

  def select(*column_names : Symbol) : Select
    Select.new(self, column_names)
  end

  # def select(&) : Select
  #   columns = with Columns.new yield
  #   Select.new(self, columns)
  # end

  def insert_into(table_name : Symbol) : Insert
    Insert.new(self, table_name)
  end

  # def update(table_name : Symbol) : Update
  #   Update.new(self, table_name)
  # end

  # def delete_from(table_name : Symbol) : Delete
  #   Update.new(self, table_name)
  # end

  def to_sql(query : Select | Insert) : {String, Array(ValueType)}
    @adapter.new.to_sql(query)
  end
end
