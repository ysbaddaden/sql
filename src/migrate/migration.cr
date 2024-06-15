class SQL::Migrate::Migration
  # :nodoc:
  PATTERN_RE = /--\s+\+migrate\s+(up|down)/

  getter version : Int64
  getter name : String
  getter path : String

  @up : Array(String)?
  @down : Array(String)?
  @parsed = Atomic(UInt8).new(0)

  getter path : String

  def initialize(@version : Int64, @name : String, @path : String)
  end

  def up : Array(String)?
    parse_once
    @up
  end

  def down : Array(String)?
    parse_once
    @down
  end

  private def parse_once
    parse if @parsed.compare_and_set(0, 1).last
  end

  # FIXME: properly lex the SQL, the crude parsing below may match `--` or `;`
  #        within plain strings for example.
  private def parse
    buffer = IO::Memory.new
    queries = nil

    File.each_line(@path, chomp: true) do |line|
      # remove trailing/leading whitespaces
      line = line.strip

      if line =~ PATTERN_RE
        case $1
        when "up"   then @up = queries = [] of String
        when "down" then @down = queries = [] of String
        end
      elsif line.starts_with?("--")
        # skip comment line
      elsif queries
        if idx = line.index("--")
          # remove trailing comment
          line = line[...idx].strip
        end

        buffer << line << '\n'

        if line.ends_with?(';')
          queries << buffer.rewind.to_s
          buffer.clear
        end
      else
        # skip line
      end
    end
  end
end
