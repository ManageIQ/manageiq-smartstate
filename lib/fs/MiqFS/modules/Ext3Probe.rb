require 'fs/ext3/superblock'

module Ext3Probe
  def self.probe(dobj)
    dobj.seek(0, IO::SEEK_SET)
    sb = Ext3::Superblock.new(dobj)

    # If initializing the superblock does not throw any errors, then this is ext3
    $log.debug("Ext3Probe << TRUE")
    return true
  rescue => err
    $log.debug "Ext3Probe << FALSE because #{err.message}"
    return false
  ensure
    dobj.seek(0, IO::SEEK_SET)
end
end
