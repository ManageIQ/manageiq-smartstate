class MiqFsError < RuntimeError
end

class MiqFsDirectoryNotFound < MiqFsError
  attr_accessor :dir

  def initialize(dir)
    super
    @dir = dir
  end
end
