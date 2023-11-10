require "colorize"
require "./database"
require "./migrations"
require "./schema"

class SQL::Migrate::CLI
  @database_url : String

  def initialize(@database_url = ENV["DATABASE_URL"])
    @command = ARGV[0]? || "all"
  end

  def run : Nil
    case @command
    when "new"
      name = ARGV[1]? || abort "fatal: missing migration name"
      version = Time.utc.to_s("%Y%m%d%H%M%S")
      filename = migrations.path.join("#{version}_#{name}.sql")

      abort "fatal: migration file already exists" if File.exists?(filename)
      Dir.mkdir_p(migrations.path) unless Dir.exists?(migrations.path)

      puts "Writing #{filename}"
      File.write(filename, <<-SQL)
      -- +migrate up
      -- write here SQL queries to update the database's schema

      -- +migrate down
      -- write here SQL queries to rollback the database's schema

      SQL

    when "create"
      puts "Creating database #{database.name}"
      database.create

    when "drop"
      puts "Dropping database #{database.name}"
      database.drop

    when "up"
      # migrate a specific migration up
      migrations.setup!

      version = get_version!
      if migrations.up?(version)
        abort "fatal: migration already up for version=#{version}"
      else
        migrations.up(version)
      end
      schema.dump unless no_dump?

    when "down"
      # migrate a specific migration down
      migrations.setup!

      version = get_version!
      if migrations.down?(version)
        abort "fatal: migration already down for version=#{version}"
      else
        migrations.down(version)
      end
      schema.dump unless no_dump?

    when "redo"
      # migrate a specific migration down then up again
      migrations.setup!

      version = get_version!
      migrations.down(version) if migrations.up?(version)
      migrations.up(version)
      schema.dump unless no_dump?

    when "all"
      # executes pending migrations from oldest to newest
      migrations.setup!

      migrations.pending.each do |migration|
        migrations.up(migration)
      end
      schema.dump unless no_dump?

    when "rollback"
      # returns the database back to the specified version
      migrations.setup!

      version = get_version!
      to = migrations.find(version)
      index = migrations.migrated.index(to).not_nil! + 1

      migrations.migrated[index..].reverse_each do |migration|
        migrations.down(migration)
      end
      schema.dump unless no_dump?

    when "check"
      # prints pending migrations
      migrations.setup!

      unless migrations.pending.empty?
        migrations.pending.each do |migration|
          puts "pending: #{migration.version} (#{migration.name})"
        end
        exit 1
      end

    when "schema:dump"
      puts "Dumping schema to db/structure.sql"
      schema.dump

    # when "schema:load"
    #   puts "Loading schema from db/structure.sql"
    #   schema.load

    when "help", "--help", "-h"
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
