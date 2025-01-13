class MiqRpmPackages
  class Sqlite < MiqRpmPackages
    def initialize(fs, dbFile)
      @fs           = fs
      @db_file_path = dbFile

      @rpmdb_tempdir = nil
      @rpmdb_path    = nil

      if fs.present?
        @rpmdb_tempdir = Dir.mktmpdir("rpmdb-")
        FileUtils.mkdir_p("#{@rpmdb_tempdir}/var/lib/rpm")

        rpmdb_tempfile = File.open("#{@rpmdb_tempdir}/var/lib/rpm/rpmdb.sqlite", "wb")
        rpmdb_file     = fs.fileOpen(@db_file_path, "r")

        loop do
          chunk = rpmdb_file.read(4_096)
          break if chunk.nil?

          rpmdb_tempfile.write(chunk)
        end

        rpmdb_tempfile.close
        rpmdb_file.close

        @rpmdb_path = rpmdb_tempfile.path
      else
        @rpmdb_path = @db_file_path
      end
    end

    def each
      require 'rpm'

      RPM.transaction(@rpmdb_tempdir) do |ts|
        ts.each do |pkg|
          yield pkg
        end
      end
    end

    def close
      FileUtils.rm_rf(@rpmdb_tempdir) if @rpmdb_tempdir
    end
  end
end
