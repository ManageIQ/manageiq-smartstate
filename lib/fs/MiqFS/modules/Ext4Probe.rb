require 'fs/ext4/superblock'

module Ext4Probe
  def self.probe(dobj)
    unless dobj.kind_of?(MiqDisk)
      $log&.debug("Ext4Probe << FALSE because Disk Object class is not MiqDisk, but is '#{dobj.class}'")
      return false
    end

    dobj.seek(0, IO::SEEK_SET)
    Ext4::Superblock.new(dobj)

    # If initializing the superblock does not throw any errors, then this is Ext4
    $log&.debug("Ext4Probe << TRUE")
    return true
  rescue => err
    $log&.debug("Ext4Probe << FALSE because #{err.message}")
    return false
  ensure
    dobj.seek(0, IO::SEEK_SET)
  end
end
