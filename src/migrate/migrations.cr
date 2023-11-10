require "db"
require "uri"
require "./migration"

class SQL::Migrate::Migrations
  @database : DB::Database?
  @all : Array(Migration)?
  @pending : Array(Migration)?
  @migrated : Array(Migration)?
  @migrated_versions : Array(Int64)?

  getter path : Path

  def initialize(@database_url : String, path : String = "db/migrations")
    @path = Path.new(path)
  end

  def setup! : Nil
    database.exec <<-SQL
      CREATE TABLE IF NOT EXISTS schema_migrations (
        version BIGINT PRIMARY KEY
      )
    SQL
  end

  def find(version : Int) : Migration
    migration = all.find { |m| m.version == version }
    migration || abort "fatal: migration not found for version=#{version}"
  end

  def all : Array(Migration)
    if migrations = @all
      return migrations
    end

    migrations = [] of Migration

    Dir.glob(@path.join("*.sql")) do |pathname|
      if pathname =~ %r{/(\d+)_([^/]+)\.sql$}
        migrations << Migration.new($1.to_i64, $2, path: pathname)
      end
    end

    @all = migrations.sort_by!(&.version)
  end

  def pending : Array(Migration)
    @pending ||= all.reject { |m| migrated_versions.includes?(m.version) }
  end

  def migrated : Array(Migration)
    @migrated ||= all - pending
  end

  def migrated_versions : Array(Int64)
    @migrated_versions ||= database.query_all(<<-SQL, as: Int64)
      SELECT version
      FROM schema_migrations
      ORDER BY version ASC
    SQL
  end

  def exists?(version : Int) : Bool
    all.any? { |m| m.version == version }
  end

  def up?(version : Int) : Bool
    exists?(version) && pending.none? { |m| m.version == version }
  end

  def down?(version : Int) : Bool
    exists?(version) && pending.any? { |m| m.version == version }
  end

  def up(version : Int) : Nil
    up find(version)
  end

  def up(migration : Migration) : Nil
    if queries = migration.up
      puts "#{migration.version}: migrate up (#{migration.name})..."

      exec_all_in_transaction(queries) do
        database.exec(<<-SQL)
          INSERT INTO schema_migrations (version)
          VALUES (#{migration.version})
        SQL
      end
    else
      abort "fatal: missing up migration in #{migration.path}"
    end
  end

  def down(version : Int) : Nil
    down find(version)
  end

  def down(migration : Migration) : Nil
    if queries = migration.down
      puts "#{migration.version}: migrate down (#{migration.name})..."

      exec_all_in_transaction(queries) do
        database.exec(<<-SQL)
          DELETE FROM schema_migrations
          WHERE version = #{migration.version}
        SQL
      end
    else
      abort "fatal: missing down migration in #{migration.path} (irreversible migration?)"
    end
  end

  private def exec_all_in_transaction(queries, &) : Nil
    database.transaction do
      queries.each { |sql| database.exec(sql) }
      yield
    end
  end

  private def database
    @database ||= DB.open(@database_url)
  end
end
