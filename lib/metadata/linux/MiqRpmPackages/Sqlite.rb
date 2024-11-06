class MiqRpmPackages
  class Sqlite < MiqRpmPackages
    def initialize(fs, dbFile)
      require "db/MiqSqlite/MiqSqlite3"
      @pkgDb = MiqSqlite3DB::MiqSqlite3.new(dbFile, fs)
    end

    def each
      @pkgDb.getTable("Packages").each_row do |pkg|
        yield pkg
      end
    end

    def close
    end
  end
end
