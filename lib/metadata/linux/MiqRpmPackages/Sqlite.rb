require "metadata/linux/LinuxPackages"
require "tmpdir"

class MiqRpmPackages
  class Sqlite < MiqRpmPackages
    def initialize(fs, dbFile)
      @fs           = fs
      @db_file_path = dbFile

      @rpmdb_tempdir = nil
      @rpmdb_path    = nil

      if fs.present?
        @rpmdb_tempdir = Dir.mktmpdir("rpmdb-")
        rpmdb_dir = File.join(@rpmdb_tempdir, rpm_db_relative)
        FileUtils.mkdir_p(rpmdb_dir)

        rpmdb_tempfile = File.open(File.join(rpmdb_dir, "rpmdb.sqlite"), "wb")
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
          tagids = %w[name version release summary description buildtime vendor arch installtime]

          result = tagids.each_with_object({}) { |tag, obj| obj[tag] = pkg[tag.to_sym] }
          # These have different tag names for the tagid
          result["category"]  = pkg[:group]
          result["depends"]   = pkg[:requirename]
          result["installed"] = true unless result.empty?

          yield MiqHashStruct.new(result)
        end
      end
    end

    def close
      FileUtils.rm_rf(@rpmdb_tempdir) if @rpmdb_tempdir
    end

    private

    def rpm_db_relative
      @rpm_db_relative ||= begin
        parts = [RbConfig::CONFIG["host_os"] =~ /darwin/ ? "opt/homebrew" : nil, "var/lib/rpm"].compact
        File.join(*parts)
      end
    end
  end
end
