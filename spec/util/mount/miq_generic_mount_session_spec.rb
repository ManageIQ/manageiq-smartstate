require "util/mount/miq_generic_mount_session"
require "awesome_spawn/spec_helper"

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

  include AwesomeSpawn::SpecHelper

  describe "#mount" do
    let(:args) { {:foo => :bar} }

    it "works on success" do
      stub_good_run!("mount", :params => args, :combined_output => true)

      described_class.new(:uri => nil).mount(args)
    end

    it "will retry with sudo on failure" do
      stub_bad_run!("mount",       :params => args, :combined_output => true)
      stub_good_run!("sudo mount", :params => args, :combined_output => true)

      described_class.new(:uri => nil).mount(args)
    end

    it "raises on failure and sudo failure" do
      stub_bad_run!("mount",      :params => args, :combined_output => true)
      stub_bad_run!("sudo mount", :params => args, :combined_output => true)

      expect { described_class.new(:uri => nil).mount(args) }.to raise_error(AwesomeSpawn::CommandResultError)
    end
  end

  describe "#sudo_mount" do
    let(:args) { {:foo => :bar} }

    it "works on success" do
      stub_good_run!("sudo mount", :params => args, :combined_output => true)

      described_class.new(:uri => nil).sudo_mount(args)
    end

    it "raises on failure" do
      stub_bad_run!("sudo mount", :params => args, :combined_output => true)

      expect { described_class.new(:uri => nil).sudo_mount(args) }.to raise_error(AwesomeSpawn::CommandResultError)
    end
  end

  describe "#umount" do
    let(:mount_point) { "/mnt/foo" }

    it "works on success" do
      stub_good_run!("umount", :params => [mount_point], :combined_output => true)

      described_class.new(:uri => nil).umount(mount_point)
    end

    it "will retry with sudo on failure" do
      stub_bad_run!("umount",       :params => [mount_point], :combined_output => true)
      stub_good_run!("sudo umount", :params => [mount_point], :combined_output => true)

      described_class.new(:uri => nil).umount(mount_point)
    end

    it "raises on failure and sudo failure" do
      stub_bad_run!("umount",      :params => [mount_point], :combined_output => true)
      stub_bad_run!("sudo umount", :params => [mount_point], :combined_output => true)

      expect { described_class.new(:uri => nil).umount(mount_point) }.to raise_error(AwesomeSpawn::CommandResultError)
    end
  end

  describe "#sudo_umount" do
    let(:mount_point) { "/mnt/foo" }

    it "works on success" do
      stub_good_run!("sudo umount", :params => [mount_point], :combined_output => true)

      described_class.new(:uri => nil).sudo_umount(mount_point)
    end

    it "raises on failure" do
      stub_bad_run!("sudo umount", :params => [mount_point], :combined_output => true)

      expect { described_class.new(:uri => nil).sudo_umount(mount_point) }.to raise_error(AwesomeSpawn::CommandResultError)
    end
  end
end
