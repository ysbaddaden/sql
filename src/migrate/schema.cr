require "db"
require "uri"

class SQL::Migrate::Schema
  @database : DB::Database?

  def initialize(@database_url : String, @path = "db/structure.sql")
    @database_uri = URI.parse(@database_url)
  end

  def dump : Nil
    case @database_uri.scheme
    when "postgres", "postgresql"
      pg_dump
      dump_metadata
    when "mysql"
      mysql_dump
      dump_metadata
    end
  end

  private def pg_dump : Nil
    args = ["--file", @path, "--schema-only", "--no-acl", "--no-owner"]
    if dbname = @database_uri.path
      args << dbname.lstrip('/')
    end
    Process.run("pg_dump", args: args, env: pg_auth)
  end

  private def pg_auth
    env = {} of String => String

    if host = @database_uri.host.presence
      env["PGHOST"] = host
    end
    if port = @database_uri.port
      env["PGPORT"] = port.to_s
    end
    if user = @database_uri.user
      env["PGUSER"] = user
    end
    if password = @database_uri.password
      env["PGPASSWORD"] = password
    end

    env
  end

  private def mysql_dump : Nil
    # TODO: mysqldump command
  end

  private def dump_metadata : Nil
    File.open(@path, "a") do |file|
      versions = database.query_all(<<-SQL, as: Int64)
        SELECT version
        FROM schema_migrations
        ORDER BY version ASC
      SQL
      versions.each do |version|
        file.puts "INSERT INTO schema_migrations (version) VALUES (#{version});"
      end
    end
  end

  private def database
    @database ||= DB.open(@database_url)
  end
end
