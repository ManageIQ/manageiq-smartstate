module MiqDiskCommon

  def self.file_mode(dInfo)
    if dInfo.mountMode.nil? || dInfo.mountMode == "r"
      dInfo.mountMode = "r"
      return "r"
    elsif dInfo.mountMode = "rw"
      return "r+"
    end
    raise "Unrecognized mountMode: #{dInfo.mountMode}"
  end

end # module
