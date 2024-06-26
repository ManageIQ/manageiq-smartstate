require 'tempfile'

require 'logger'
$log = Logger.new(File.expand_path("../../../../log/#{File.basename(__FILE__, ".*")}.log", __dir__))

require 'metadata/MIQExtract/MIQExtract'
require 'manageiq/gems/pending'
require 'util/miq-process'
require 'sys-uname'

PROFILE_INIT = false
PROFILE_EXTRACT = false

begin
  vmCfgFile = nil

  startTime = Time.now
  vms_path  = File.join((Sys::Platform::IMPL == :macosx ? "/Volumes" : "/mnt"), "manageiq", "fleecing_test", "images", "virtual_machines")
  vmCfgFile = File.join(vms_path, "vmware", "JanusVM", "JanusVM-17-sep-2007", "JanusVM", "JanusVM.vmx")

  # Load VM config file
  ost = OpenStruct.new
  vmCfg = if PROFILE_INIT
            profile_block(:file_prefix => "init_") { MIQExtract.new(vmCfgFile, ost) }
          else
            MIQExtract.new(vmCfgFile, ost)
          end

  $log.info "******************** Memory    : [#{MiqProcess.processInfo.inspect}] ********************"
  %w(vmconfig vmevents accounts software services system).each do |c|
    $log.warn "Start fleece for [#{c}]"
    stf = Time.now

    xml = if PROFILE_EXTRACT
            profile_block(:file_prefix => "#{c}_") { vmCfg.extract([c]) }
          else
            vmCfg.extract([c])
          end

    $log.warn "Fleece for [#{c}] completed [#{Time.now - stf}]"

    $log.info "[#{c}] extract return xml of type [#{xml.class}]" if xml
    File.open(Tempfile.new("extract_#{c}.xml"), "w") { |f| xml.write(f, 2) } if xml
  end
  $log.info "******************** Memory    : [#{MiqProcess.processInfo.inspect}] ********************"

  # Unmounts the VM
  vmCfg.close

  $log.info "START TIME: [#{startTime}]"
  $log.info "STOP TIME : [#{Time.now}]"
  $log.info "Run  time : [#{(Time.now - startTime)}] seconds"

# Use this time to check for memory usage through OS utilities
#  $log.info "Sleeping for 5 seconds"
#  sleep(5)

rescue NameError => err
  unless err.to_s.include?("MiqVm")
    $log.warn err
    $log.fatal err.backtrace.join("\n")
  end
rescue => err
  $log.fatal err.to_s
  err.backtrace.each { |e| $log.fatal e }
end

$log.info "MIQExtract ending."
