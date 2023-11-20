require "./operators"

class SQL
  class Function
    include Operators

    getter name : Symbol
    getter? args : Array(Expression | Symbol)?

    def initialize(@name, @args = nil)
    end

    def over(&partition) : Over
      Over.new(self, partition)
    end

    def to_sql(builder : Builder) : Nil
      builder.sql << name
      builder.sql << '('
      if args = args?
        builder.to_sql(args)
      end
      builder.sql << ')'
    end
  end

  # :nodoc:
  class Function::Substring < Function
    @string : Expression
    @start : Expression?
    @length : Expression?

    def initialize(@string, @start = nil, @length = nil)
      super :substring
    end

    def to_sql(builder : Builder) : Nil
      builder.sql << @name << '('

      if start = @start
        builder.sql << " FROM "
        builder.sql << start
      end

      if length = @length
        builder.sql << " FOR "
        builder.sql << length
      end

      builder.sql << ')'
    end
  end

  # :nodoc:
  class Function::Position < Function
    @substring : Expression
    @string : Expression

    def initialize(@substring, @string)
      super :position
    end

    def to_sql(builder : Builder) : Nil
      builder.sql << @name << '('
      builder.sql << @substring
      builder.sql << " IN "
      builder.sql << @string
      builder.sql << ')'
    end
  end

  class Over
    getter fn : Function
    getter partition : Proc(Nil)

    def initialize(@fn, @partition)
    end
  end

  module Functions
    # Registers a helper method to create a `SQL::Function`. By default the
    # generated method will take and pass arguments, you may specify
    # `args: false` to generate a method without arguments.
    macro register_function(name, *, args = true)
      {% if args %}
        @[AlwaysInline]
        def {{name.id}}(*args) : Function
          Function.new({{name.id.symbolize}}, [*args] of Expression)
        end
      {% else %}
        @[AlwaysInline]
        def {{name.id}} : Function
          Function.new({{name.id.symbolize}})
        end
      {% end %}
    end

    # aggregates

    register_function :avg
    register_function :bit_and
    register_function :bit_count
    register_function :bit_length
    register_function :bit_or
    register_function :bit_xor
    register_function :count      # TODO: COUNT(DISTINCT ...)
    register_function :max
    register_function :min
    register_function :sum

    # comparisons

    register_function :coalesce
    register_function :greatest
    register_function :least
    register_function :nullif

    # math

    register_function :abs
    register_function :acos
    register_function :asin
    register_function :atan
    register_function :atan2
    register_function :ceil
    register_function :cos
    register_function :cot
    register_function :degrees
    register_function :exp
    register_function :floor
    register_function :ln
    register_function :log
    register_function :log10
    register_function :log2
    register_function :mod
    register_function :pi, args: false
    register_function :power
    register_function :radians
    register_function :round
    register_function :sign
    register_function :sin
    register_function :sqrt
    register_function :tan

    # string

    register_function :ascii
    register_function :char_length
    register_function :character_length
    register_function :concat
    register_function :concat_ws
    register_function :left
    register_function :length
    register_function :lower
    register_function :lpad
    register_function :ltrim
    register_function :md5
    register_function :octet_length
    register_function :repeat
    register_function :regexp_instr
    register_function :regexp_like
    register_function :regexp_replace
    register_function :regexp_substr
    register_function :replace
    register_function :reverse
    register_function :right
    register_function :rpad
    register_function :rtrim
    register_function :substr
    register_function :trim
    register_function :upper

    # time functions

    register_function :current_date, args: false
    register_function :current_time
    register_function :current_timestamp
    register_function :date_add
    register_function :now, args: false

    # window

    register_function :cume_dist
    register_function :dense_rank
    register_function :first_value
    register_function :lag
    register_function :last_value
    register_function :lead
    register_function :nth_value
    register_function :ntile
    register_function :percent_rank
    register_function :rank
    register_function :row_number

    @[AlwaysInline]
    def substring(string, start, length)
      Function::Substring.new(string, start, length)
    end

    @[AlwaysInline]
    def position(string, start, length)
      Function::Position.new(string, start, length)
    end
  end
end
