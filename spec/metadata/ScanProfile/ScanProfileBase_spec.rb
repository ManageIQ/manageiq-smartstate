require 'metadata/ScanProfile/HostScanProfiles'
require 'metadata/ScanProfile/VmScanProfiles'

describe ScanProfilesBase do
  describe ".get_class" do
    context "HostScan" do
      it "returns HostScanProfile.class with 'profile' parameter" do
        klass = described_class.get_class('profile', HostScanProfiles.scan_profiles_class)
        expect(klass).to be_a(HostScanProfile.class) 
      end

      it "returns HostScanItem.class with 'item' parameter" do
        klass = described_class.get_class('item', HostScanProfiles.scan_profiles_class)
        expect(klass).to be_a(HostScanItem.class)
      end
    end

    context "VmScan" do
      it "returns VmScanProfile.class  with 'profile' parameter" do
        klass = described_class.get_class('profile', VmScanProfiles.scan_profiles_class)
        expect(klass).to be_a(VmScanProfile.class)
      end

      it "returns VmScanProfile.class with 'item' parameter" do
        klass = described_class.get_class('item', VmScanProfiles.scan_profiles_class)
        expect(klass).to be_a(VmScanItem.class)
      end
    end
  end
end
