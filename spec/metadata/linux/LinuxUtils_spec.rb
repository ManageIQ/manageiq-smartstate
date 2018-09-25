require 'metadata/linux/LinuxUtils'

describe MiqLinux::Utils do
  let(:opentack_systemctl_services) do
    <<~EOS
      openstack-nova-api:                     active
      openstack-nova-cert:                    inactive  (disabled on boot)
      openstack-nova-compute:                 active
      openstack-nova-network:                 inactive  (disabled on boot)
      openstack-nova-scheduler:               active
      openstack-nova-conductor:               active
      openstack-glance-api:                   active
      openstack-glance-registry:              active
      openstack-keystone:                     active
      openstack-swift-proxy:                  active
      openstack-swift-account:                active
      openstack-swift-container:              active
      openstack-swift-object:                 active
      openstack-ceilometer-api:               active
      openstack-ceilometer-central:           active
      openstack-ceilometer-compute:           inactive  (disabled on boot)
      openstack-ceilometer-collector:         active
      openstack-ceilometer-alarm-notifier:    active
      openstack-ceilometer-alarm-evaluator:   active
      openstack-ceilometer-notification:      active
      openstack-heat-api:                     active
      openstack-heat-api-cfn:                 active
      openstack-heat-api-cloudwatch:          active
      openstack-heat-engine:                  active
    EOS
  end

  let(:openstack_container_services) do
    <<~EOS
      aodh_listener              Up 7 days (healthy)
      heat_api_cron              Up 7 days
      swift_container_auditor    Up 7 days
      swift_object_expirer       Up 7 days
      swift_object_updater       Up 7 days
      swift_container_replicator Up 7 days
      swift_account_auditor      Up 7 days
      cinder_api_cron            Up 7 days
    EOS
  end

  describe '#parse_openstack_status' do
    let(:subject) { MiqLinux::Utils.parse_openstack_status(opentack_systemctl_services) }

    it "should return Array" do
      is_expected.to be_a Array
    end

    it "should have 6 OpenStack services" do
      expect(subject.count).to be_equal 6
    end

    %w(Nova Glance Keystone Swift Ceilometer Heat).map do |service|
      it "should have contain correct OpenStack #{service} service" do
        expect(subject.count { |service_hash| service_hash['name'].include?(service) }).to be_equal 1
      end
    end

    describe "Nova services" do
      let(:subject) do
        MiqLinux::Utils.parse_openstack_status(opentack_systemctl_services).find { |service| service['name'].include?('Nova') }['services']
      end

      it "should have 6 services total" do
        expect(subject.count).to be_equal 6
      end

      it "should have 4 active services" do
        expect(subject.count { |service| service['active'] }).to be_equal 4
      end

      it "should have 2 inactive services" do
        expect(subject.count { |service| !service['active'] }).to be_equal 2
      end
    end
  end

  describe '#parse_openstack_container_status' do
    let(:subject) { MiqLinux::Utils.parse_openstack_container_status(openstack_container_services) }

    it "should return Array" do
      is_expected.to be_a Array
    end

    it "should have 4 OpenStack services" do
      expect(subject.count).to be_equal 4
    end

    %w(Cinder Aodh Swift Heat).map do |service|
      it "should have contain correct OpenStack #{service} service" do
        expect(subject.count { |service_hash| service_hash['name'].include?(service) }).to be_equal 1
      end
    end

    it 'should return an array of hashes' do
      parsed_container_status_list = [{"name" => "Aodh", "services" => [{"name" => "aodh_listener", "active" => true, "enabled" => true}]},
                                      {"name" => "Heat", "services" => [{"name" => "heat_api_cron", "active" => true, "enabled" => true}]},
                                      {"name" => "Swift", "services" => [{"name" => "swift_container_auditor", "active" => true, "enabled" => true},
                                                                         {"name" => "swift_object_expirer", "active" => true, "enabled" => true},
                                                                         {"name" => "swift_object_updater", "active" => true, "enabled" => true},
                                                                         {"name" => "swift_container_replicator", "active" => true, "enabled" => true},
                                                                         {"name" => "swift_account_auditor", "active" => true, "enabled" => true}]},
                                      {"name" => "Cinder", "services" => [{"name" => "cinder_api_cron", "active" => true, "enabled" => true}]}]
      expect(subject).to eq parsed_container_status_list
    end
  end

  describe '#merge_openstack_services' do
    let(:subject) do
      systemctl_services = MiqLinux::Utils.parse_openstack_status(opentack_systemctl_services)
      containerized_services = MiqLinux::Utils.parse_openstack_container_status(openstack_container_services)
      MiqLinux::Utils.merge_openstack_services(systemctl_services, containerized_services)
    end

    it "should return Array" do
      is_expected.to be_a Array
    end

    it "should have 6 services total" do
      expect(subject.count).to be_equal 8
    end

    %w(Cinder Aodh Swift Heat Nova Glance Keystone Ceilometer Aodh).map do |service|
      it "should have contain correct OpenStack #{service} service" do
        expect(subject.count { |service_hash| service_hash['name'].include?(service) }).to be_equal 1
      end
    end

    it "should merge 2 outputs" do
      swift = subject.select { |service| service['name'] == 'Swift' }.first
      service_names = ["openstack-swift-proxy",
                       "openstack-swift-account",
                       "openstack-swift-container",
                       "openstack-swift-object",
                       "swift_container_auditor",
                       "swift_object_expirer",
                       "swift_object_updater",
                       "swift_container_replicator",
                       "swift_account_auditor"]
      expect(swift["services"].all? { |service| service_names.include?(service["name"]) }).to be true
    end
  end
end
