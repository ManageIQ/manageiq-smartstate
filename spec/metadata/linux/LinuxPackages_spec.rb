require 'metadata/linux/LinuxPackages'

describe MiqLinux::Packages do
  let(:fs) { double("MiqFS") }

  before do
    allow(fs).to receive(:fileExists?).and_return(false)
    allow(fs).to receive(:fileDirectory?).and_return(false)
  end

  context "with a dpkg status file" do
    before do
      expect(fs).to receive(:fileExists?).with(MiqLinux::Packages::DPKG_FILE).and_return(true)
      expect(fs)
        .to receive(:fileOpen)
        .with(MiqLinux::Packages::DPKG_FILE)
        .and_yield(File.open(File.expand_path("data/dpkg/status", __dir__), "r"))
    end

    it "returns a list of rpm packages" do
      result = described_class.new(fs)

      expect(result.instance_variable_get(:@packages).count).to eq(1)
    end

    it "returns relevent information for each package" do
      result = described_class.new(fs)
      kernel = result.instance_variable_get(:@packages).first

      expect(kernel.to_h).to include(
        :name        => "linux-image-6.11.4-amd64",
        :status      => "install ok installed",
        :installed   => true,
        :category    => "kernel",
        :description => "Linux 6.11 for 64-bit PCs (signed)\n The Linux kernel 6.11 and modules for use on PCs with AMD64, Intel 64 or\n VIA Nano processors.\n .\n The kernel image is signed for use with Secure Boot.\nBuilt-Using: linux (= 6.11.4-1)\nHomepage: https://www.kernel.org/",
        :version     => "6.11.4-1",
        :depends     => "kmod, linux-base (>= 4.3~), initramfs-tools (>= 0.120+deb8u2) | linux-initramfs-tool"
      )
    end
  end

  context "with an RPM directory" do
    before do
      expect(fs).to receive(:fileDirectory?).with(MiqLinux::Packages::RPM_DB).and_return(true)
      expect(fs).to receive(:fileExists?).with(File.join(MiqLinux::Packages::RPM_DB, "Packages")).and_return(true)
    end

    context "with a Packages Berkeley DB file" do
      before do
        expect(fs)
          .to receive(:fileOpen)
          .with(File.join(MiqLinux::Packages::RPM_DB, "Packages"), "r")
          .and_return(File.open(File.expand_path('../../db/MiqBdb/data/rpm/Packages', __dir__), "r"))
      end

      it "returns a list of rpm packages" do
        result = described_class.new(fs)

        expect(result.instance_variable_get(:@packages).count).to eq(690)
      end

      it "returns relevent information for each package" do
        result = described_class.new(fs)
        kernel = result.instance_variable_get(:@packages).detect { |p| p.name == 'kernel' }

        expect(kernel.to_h).to include(
          "name"      => "kernel",
          "version"   => "2.4.21",
          "release"   => "50.EL",
          "summary"   => "The Linux kernel (the core of the Linux operating system)",
          "vendor"    => "Red Hat, Inc.",
          "category"  => "System Environment/Kernel",
          "arch"      => "i686",
          "depends"   => "rpmlib(VersionedDependencies)\nfileutils\nmodutils\ninitscripts\nmkinitrd\n/bin/sh\nrpmlib(PayloadFilesHavePrefix)\nrpmlib(CompressedFileNames)",
          "installed" => true
        )
      end
    end
  end

  context "with a conarydb file" do
    before do
      expect(fs).to receive(:fileExists?).with(MiqLinux::Packages::CONARY_FILE).and_return(true)
      expect(fs)
        .to receive(:fileOpen)
        .with(MiqLinux::Packages::CONARY_FILE, "r")
        .and_return(File.open(File.expand_path('../../db/MiqSqlite/conary.db', __dir__), "r"))
      expect(fs).to receive(:fileSize).twice.with(MiqLinux::Packages::CONARY_FILE).and_return(File.size(File.expand_path('../../db/MiqSqlite/conary.db', __dir__)))
    end

    it "returns a list of packages" do
      result = described_class.new(fs)

      expect(result.instance_variable_get(:@packages).count).to eq(212)
    end

    it "returns relevant information for each package" do
      result = described_class.new(fs)
      kernel = result.instance_variable_get(:@packages).detect { |p| p.name == 'kernel' }

      expect(kernel.to_hash).to include(
        :name      => "kernel",
        :version   => "/conary.rpath.com@rpl:devel//1/2.6.19.7-0.3-1",
        :installed => true
      )
    end
  end
end
