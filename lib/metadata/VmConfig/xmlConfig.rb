require 'manageiq/gems/pending'
require 'util/miq-xml'
require 'awesome_spawn'

module XmlConfig
  def convert(filename)
    @convertText = ""
    # $log.debug "Processing Windows Configuration file [#{filename}]"

    xml_data = nil
    unless File.file?(filename)
      require 'sys-uname'
      if Sys::Platform::IMPL == :linux
        begin
          # First check to see if the command is available
          AwesomeSpawn.run!("virsh", :params => ["list"])
          begin
            xml_data = AwesomeSpawn.run!("virsh", :params => ["dumpxml", File.basename(filename, ".*")], :combined_output => true).output
          rescue => err
            $log.error "#{err}\n#{err.backtrace.join("\n")}"
          end
        rescue
        end
      end
      raise "Cannot open config file: [#{filename}]" if xml_data.blank?
    end

    if xml_data.nil?
      fileSize = File.size(filename)
      raise "Specified XML file [#{filename}] is not a valid VM configuration file." if fileSize > 104857
      xml = MiqXml.loadFile(filename)
      if xml.encoding == "UTF-16" && xml.root.nil? && Object.const_defined?('Nokogiri')
        xml_data = File.open(filename) { |f| Nokogiri::XML(f) }.to_xml(:encoding => "UTF-8")
        xml = MiqXml.load(xml_data)
      end
    else
      xml = MiqXml.load(xml_data)
    end
    xml_type = nil
    xml_type = :xen unless xml.find_first("//vm/thinsyVmm").nil?
    xml_type = :kvm if xml.root.name == 'domain' && ['kvm', 'qemu'].include?(xml.root.attributes['type'])

    raise "Specified XML file [#{filename}] is not a valid VM configuration file." if xml_type.nil?

    xml_to_config(xml)

    @convertText
  end

  def xml_to_config(xml)
    xml.each_recursive { |e| send(e.name, e) if self.respond_to?(e.name) && !['id', 'type'].include?(e.name.downcase) }
  end

  def vm(element)
    add_item("displayName", element.attributes['name'])
    add_item("memsize", element.attributes['minmem'])
  end

  def vmmversion(element)
    add_item("config.version", element.text)
  end

  def vdisk(element)
    index = element.attributes['index'].to_i
    add_item("scsi0:#{index}.fileName", element.elements[1].text)
  end

  def add_item(var, value)
    @convertText += "#{var} = \"#{value}\"\n"
  end

  def vendor
    "xen"
  end
end
