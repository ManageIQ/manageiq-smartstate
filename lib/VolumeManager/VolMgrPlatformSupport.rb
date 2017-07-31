class VolMgrPlatformSupport
  def initialize(cfgFile, ost)
    $log.debug "Initializing VolMgrPlatformSupport" if $log
    @cfgFile = cfgFile
    @ost = ost

    require "VolumeManager/VolMgrPlatformSupportLinux"
    extend VolMgrPlatformSupportLinux
    init
  end # def initialize
end # class VolMgrPlatformSupport
