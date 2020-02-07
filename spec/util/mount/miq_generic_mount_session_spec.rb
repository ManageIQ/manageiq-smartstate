require "util/mount/miq_generic_mount_session"

describe MiqGenericMountSession do
  it "#connect returns a string pointing to the mount point" do
    allow(described_class).to receive(:raw_disconnect)
    s = described_class.new(:uri => '/tmp/abc')
    s.logger = Logger.new("/dev/null")

    result = s.connect
    expect(result).to     be_kind_of(String)
    expect(result).to_not be_blank

    s.disconnect
  end

  it "#mount_share is unique" do
    expect(described_class.new(:uri => '/tmp/abc').mount_share).to_not eq(described_class.new(:uri => '/tmp/abc').mount_share)
  end

  it ".runcmd will retry with sudo if needed" do
    cmd      = "mount"
    args     = "--foo bar"
    fake_out = "uh oh"
    fake_err = "err: not good"

    cmd_bad_result  = AwesomeSpawn::CommandResult.new("#{cmd} #{args}", fake_out, fake_err, 1)
    cmd_error       = AwesomeSpawn::CommandResultError.new("mount failed", cmd_bad_result)
    cmd_good_result = AwesomeSpawn::CommandResult.new("sudo #{cmd} #{args}", "", "", 0)

    spawn_args      = { :foo => :bar, :combined_output => true }

    expect(AwesomeSpawn).to receive(:run!).once.with(cmd, spawn_args).and_raise(cmd_error)
    expect(AwesomeSpawn).to receive(:run!).once.with("sudo #{cmd}", spawn_args).and_return(cmd_good_result)

    described_class.runcmd("mount", :foo => :bar)
  end
end
