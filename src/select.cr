require "./where"

class SQL
  class Select
    @sql : SQL

    getter columns : Enumerable(Symbol)
    getter from : Symbol?
    getter? condition : Expression?

    def initialize(@sql, @columns)
    end

    def from(@from : Symbol) : self
      self
    end

    def where(&) : self
      @condition = with Where.new yield
      self
    end

    # @[AlwaysInline]
    # def query_one(*, as type : F) : F forall F
    #   @sql.db.query_one(*to_sql, as: type)
    # end

    # @[AlwaysInline]
    # def query_one : DB::ResultSet
    #   @sql.db.query_one(*to_sql)
    # end

    # @[AlwaysInline]
    # def query_one?(*, as type : F) : F? forall F
    #   @sql.db.query_one?(*to_sql, as: type)
    # end

    # @[AlwaysInline]
    # def query_one? : DB::ResultSet?
    #   @sql.db.query_one?(*to_sql)
    # end

    # @[AlwaysInline]
    # def query_all : Array(DB::ResultSet)
    #   @sql.db.query_all(*to_sql)
    # end

    # @[AlwaysInline]
    # def query_all(& : DB::ResultSet ->) : Nil
    #   @sql.db.query_all(*to_sql) { |rs| yield rs }
    # end

    # @[AlwaysInline]
    # def query_all(*, as type : F) : Array(F) forall F
    #   @sql.db.query_all(*to_sql, as: type)
    # end

    # @[AlwaysInline]
    # def query_all(*, as type : F, & : F ->) : Nil forall F
    #   @sql.db.query_all(*to_sql, as: type) { |rs| yield rs }
    # end

    # @[AlwaysInline]
    # def scalar : ValueType
    #   @sql.db.scalar(*to_sql)
    # end

    @[AlwaysInline]
    def to_sql : {String, Array(ValueType)}
      @sql.to_sql(self)
    end
  end
end
