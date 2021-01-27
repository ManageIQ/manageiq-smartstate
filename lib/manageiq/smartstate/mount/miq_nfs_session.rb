require 'util/mount/miq_generic_mount_session'

class MiqNfsSession < MiqGenericMountSession
  PORTS = [2049, 111]

  def self.uri_scheme
    "nfs".freeze
  end

  def initialize(log_settings)
    super(log_settings.merge(:ports => PORTS))
  end

  def connect
    scheme, userinfo, @host, port, registry, @mount_path, opaque, query, fragment = URI.split(URI.encode(@settings[:uri]))
    super
  end

  def mount_share
    super

    log_header = "MIQ(#{self.class.name}-mount_share)"
    logger.info("#{log_header} Connecting to host: [#{@host}], share: [#{@mount_path}] using mount point: [#{@mnt_point}]...")
    # URI: nfs://192.168.252.139/exported/miq
    # mount 192.168.252.139:/exported/miq /mnt/miq

    mount_args      = {:t => "nfs"}
    mount_args[:r]  = nil if settings_read_only?
    mount_args[nil] = %W[#{@host}:#{@mount_path} #{@mnt_point}]

    # Quote the host:exported directory since the directory can have spaces in it
    case Sys::Platform::IMPL
    when :macosx
      mount_args[:o] = "resvport"
      sudo_mount(mount_args)
    when :linux
      mount(mount_args)
    else
      raise "platform not supported"
    end
    logger.info("#{log_header} Connecting to host: [#{@host}], share: [#{@mount_path}]...Complete")
  end
end
