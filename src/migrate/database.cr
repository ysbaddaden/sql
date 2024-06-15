require "db"
require "uri"

class SQL::Migrate::Database
  getter name : String

  @database : DB::Database?
  @url : String

  def initialize(database_url : String)
    uri = URI.parse(database_url)
    @name = uri.path.gsub('/', "")

    case uri.scheme
    when "postgres"
      uri.path = uri.user.to_s
    when "mysql"
      # TODO
    when "sqlite3"
      # TODO
    end
    @url = uri.to_s
  end

  def create : Nil
    database.exec <<-SQL
      CREATE DATABASE "#{@name}"
    SQL
  end

  def drop : Nil
    database.exec <<-SQL
      DROP DATABASE "#{@name}"
    SQL
  end

  private def database
    @database ||= DB.open(@url)
  end
end
