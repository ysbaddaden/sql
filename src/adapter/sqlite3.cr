require "./adapter"

class SQL
  struct Adapter::SQLite3 < Adapter
  end

  Adapter.register("sqlite3", Adapter::SQLite3)
end
