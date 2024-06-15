require "./query"
require "./information_schema"

module SQL
  # Shortcut for `SQL::Query.new`.
  @[AlwaysInline]
  def self.query(database_uri : String | URI) : Query
    Query.new(database_uri)
  end

  # Shortcut for `SQL::Query.new`.
  @[AlwaysInline]
  def self.query(builder_class : Query::Builder::Generic.class) : Query
    Query.new(builder_class)
  end
end
