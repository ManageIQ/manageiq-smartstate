module MiqDiskCommon
  def self.file_mode(d_info)
    if d_info.mountMode.nil? || d_info.mountMode == "r"
      d_info.mountMode = "r"
      return "r"
    elsif d_info.mountMode == "rw"
      return "r+"
    end
    raise "Unrecognized mountMode: #{d_info.mountMode}"
  end
end
