require 'db/MiqBdb/MiqBdb'

db = MiqBerkeleyDB::MiqBdb.new("Name")
db.each_key { |k| puts "Name: #{k}:" }
db.close
