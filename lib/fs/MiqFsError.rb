class MiqFsError < RuntimeError
end

class DirectoryNotFound < MiqFsError
  attr_accessor :dir

  def initialize(dir)
    super
    @dir = dir
  end
end
