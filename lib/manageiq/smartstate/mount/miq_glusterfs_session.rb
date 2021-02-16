require 'util/mount/miq_generic_mount_session'

class MiqGlusterfsSession < MiqGenericMountSession
  PORTS = [2049, 111].freeze

  def self.uri_scheme
    "glusterfs".freeze
  end

  def initialize(log_settings)
    super(log_settings.merge(:ports => PORTS))
  end

  def connect
    _scheme, _userinfo, @host, _port, _registry, @mount_path, _opaque, _query, _fragment =
      URI.split(URI::DEFAULT_PARSER.escape(@settings[:uri]))
    super
  end

  def mount_share
    super

    log_header = "MIQ(#{self.class.name}-mount_share)"
    logger.info(
      "#{log_header} Connecting to host: [#{@host}], share: [#{@mount_path}] using mount point: [#{@mnt_point}]...")

    mount_args      = {:t => "glusterfs"}
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
