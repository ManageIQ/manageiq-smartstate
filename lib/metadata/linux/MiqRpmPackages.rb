

# RPM Specification located at: http://jrpm.sourceforge.net/rpmspec/index.html

require_relative "MiqRpmPackages/Bdb"
require_relative "MiqRpmPackages/Sqlite"

class MiqRpmPackages
  class << self
    private

    alias orig_new new
  end

  def self.new(fs, dbDir)
    if self == MiqRpmPackages
      if fs.fileExists?(File.join(dbDir, "Packages"))
        MiqRpmPackages::Bdb.new(fs, File.join(dbDir, "Packages"))
      elsif fs.fileExists?(File.join(dbDir, "rpmdb.sqlite"))
        MiqRpmPackages::Sqlite.new(fs, File.join(dbDir, "rpmdb.sqlite"))
      else
        raise ArgumentError, "Invalid RPM database"
      end
    else
      orig_new(fs, dbDir)
    end
  end
end # class MiqRPM

if __FILE__ == $0
  rpmPkgs = MiqRpmPackages.new(nil, "/var/lib/rpm/Packages")
  rpmPkgs.each do |pkg|
    puts "Package: #{pkg.name}"
    puts "\tInstall Time: #{pkg.installtime}"
    puts "\tBuild Time: #{pkg.buildtime}"
    puts "\tVersion: #{pkg.version}"
    puts "\tRelease: #{pkg.release}"
    puts "\tSummary: #{pkg.summary}"
    puts "\tVendor: #{pkg.vendor}"
    puts "\tArchitecture: #{pkg.arch}"
    puts "\tCategory: #{pkg.category}"
    puts "\tDescription: #{pkg.description}"
    puts "\tURL: #{pkg.url}"
    puts "\tDepends: #{pkg.depends}"
  end
end
