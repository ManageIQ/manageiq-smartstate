class MiqRpmPackages
  class Sqlite < MiqRpmPackages
    def initialize(fs, dbFile)
      @fs           = fs
      @db_file_path = dbFile

      @rpmdb_tempfile = nil
      @rpmdb_path     = nil

      if fs.present?
        rpmdb_file      = fs.fileOpen(@db_file_path, "r")
        @rpmdb_tempfile = Tempfile.new("rpmdb", :binmode => true)

        loop do
          chunk = rpmdb_file.read(1024)
          break if chunk.nil?

          @rpmdb_tempfile.write(chunk)
        end

        @rpmdb_tempfile.close
        rpmdb_file.close

        @rpmdb_path = @rpmdb_tempfile.path
      else
        @rpmdb_path = @db_file_path
      end
    end

    def each
    end

    def close
      if @rpmdb_tempfile
        @rpmdb_tempfile.close
        @rpmdb_tempfile.unlink
      end
    end
  end
end
