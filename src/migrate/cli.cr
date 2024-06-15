require "colorize"
require "./database"
require "./migrations"
require "./schema"

class SQL::Migrate::CLI
  @database_url : String

  def initialize(@database_url = ENV["DATABASE_URL"])
    @command = ARGV[0]? || "all"
  end

  # ameba:disable Metrics/CyclomaticComplexity
  def run : Nil
    case @command
    when "new"
      new_command ARGV[1]? || abort "fatal: missing migration name"
    when "create"
      create_command
    when "drop"
      drop_command
    when "up"
      up_command get_version!
    when "down"
      down_command get_version!
    when "redo"
      redo_command get_version!
    when "all"
      all_command
    when "rollback"
      rollback_command get_version!
    when "check"
      exit 1 if check_command
    when "schema:dump"
      schema_dump_command
    when "schema:load"
      schema_load_command
    when "help", "--help", "-h"
      help_command
    else
      abort "fatal: unknown command #{@command}"
    end
  rescue ex
    if ENV["BACKTRACE"]? == "1"
      raise ex
    else
      abort "Error: #{ex.message} (#{ex.class.name})"
    end
  end

  # Generate a new migration file.
  def new_command(migration_name : String) : Nil
    version = Time.utc.to_s("%Y%m%d%H%M%S")
    filename = migrations.path.join("#{version}_#{migration_name}.sql")

    abort "fatal: migration file already exists" if File.exists?(filename)
    Dir.mkdir_p(migrations.path) unless Dir.exists?(migrations.path)

    puts "Writing #{filename}"

    File.write(filename, <<-SQL)
    -- +migrate up
    -- write here SQL queries to update the database's schema

    -- +migrate down
    -- write here SQL queries to rollback the database's schema

    SQL
  end

  # Create the database.
  def create_command : Nil
    puts "Creating database #{database.name}"
    database.create
  end

  # Drop the database.
  def drop_command : Nil
    puts "Dropping database #{database.name}"
    database.drop
  end

  # Migrate a specific migration up.
  def up_command(version : Int64) : Nil
    migrations.setup!

    if migrations.up?(version)
      abort "fatal: migration already up for version=#{version}"
    else
      migrations.up(version)
    end

    schema.dump unless no_dump?
  end

  # Migrate a specific migration down.
  def down_command(version : Int64) : Nil
    migrations.setup!

    if migrations.down?(version)
      abort "fatal: migration already down for version=#{version}"
    else
      migrations.down(version)
    end

    schema.dump unless no_dump?
  end

  # Migrate a specific migration down then up again.
  def redo_command(version : Int64) : Nil
    migrations.setup!

    migrations.down(version) if migrations.up?(version)
    migrations.up(version)

    schema.dump unless no_dump?
  end

  # Executes pending migrations from oldest to newest
  def all_command : Nil
    migrations.setup!

    migrations.pending.each do |migration|
      migrations.up(migration)
    end

    schema.dump unless no_dump?
  end

  # Returns the database back to the specified version
  def rollback_command(version : Int64) : Nil
    migrations.setup!

    to = migrations.find(version)
    index = migrations.migrated.index!(to) + 1

    migrations.migrated[index..].reverse_each do |migration|
      migrations.down(migration)
    end

    schema.dump unless no_dump?
  end

  # Prints pending migrations. Returns true if there are pending migrations.
  def check_command : Bool
    migrations.setup!

    return false if migrations.pending.empty?

    migrations.pending.each do |migration|
      puts "pending: #{migration.version} (#{migration.name})"
    end

    true
  end

  # Dumps the database schema into `db/structure.sql`.
  def schema_dump_command : Nil
    puts "Dumping schema to db/structure.sql"
    schema.dump
  end

  # Loads the schema from `db/structure.sql` into the database.
  def schema_load_command : Nil
    raise NotImplementedError.new("Command schema:load hasn't been implemented (yet)")
    # puts "Loading schema from db/structure.sql"
    # schema.load
  end

  # Prints the help message.
  def help_command : Nil
    print <<-PLAIN
    Usage : bin/migrate <command> [<args>] [<options>]

    Available commands:

      new NAME     generate a new migration file into db/migrations

      create       create the database
      drop         drop the database

      check        print pending migrations
      all          execute all pending migrations from oldest to newest (default)
      rollback     return the database back to the specified VERSION=

      up           run a specific migration up
      down         run a specific migration down
      redo         run a specific migration down then up again

      schema:dump  dump the schema into db/structure.sql
      schema:load  load the schema from db/structure.sql [TODO]

    Options:

      --no-dump    don't update db/structure.sql after migrating

    PLAIN
  end

  protected def database
    @database ||= Migrate::Database.new(@database_url)
  end

  protected def schema
    @schema ||= Migrate::Schema.new(@database_url)
  end

  protected def migrations
    @migrations ||= Migrate::Migrations.new(@database_url)
  end

  private def abort(message, status = 1)
    ::abort(message.colorize(:red).bold, status)
  end

  private def get_version!
    ARGV.each do |arg|
      if arg.starts_with?("VERSION=")
        return arg[8..].to_i64
      end
    end
    abort "fatal: you must specify a version (e.g. VERSION=123)"
  end

  private def no_dump?
    ARGV.any? { |arg| arg == "--no-dump" }
  end
end
