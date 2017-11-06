class VMPlatformMount
  def initialize(dInfo, ost)
    $log.debug "Initializing VMPlatformMount" if $log
    @dInfo = dInfo
    @ost = ost

    require "metadata/VMMount/VMPlatformMountLinux"
    extend VMPlatformMountLinux
    init
  end # def initialize
end # class VMPlatformMount
