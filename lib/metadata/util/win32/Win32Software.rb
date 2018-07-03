require 'util/xml/xml_utils'
require 'util/miq-xml'
require 'metadata/util/win32/peheader'

module MiqWin32
  class Software
    attr_reader :applications, :patches, :product_keys

    PRODUCTS_MAPPING = [
      'DisplayName', :name,
      'Publisher', :vendor,
      'DisplayVersion', :version,
      'Comments', :description,
      'InstallLocation', :path,
      #     'PackageName', :package_name,
      #     'ProductIcon', :product_icon,
      #     'PackageName', :package_name,
    ]

    APP_PATHS_MAPPING = [
      'FileDescription', :name,
      'CompanyName', :vendor,
      'ProductVersion', :version,
      'FileDescription', :description,
      'ProductName', :package_name,
      'lang', :language,
      'path', :path,
    ]

    UNINSTALL_MAPPING = [
      'DisplayName', :name,
      'Publisher', :vendor,
      'DisplayVersion', :version,
      'FileDescription', :description,
      'ReleaseType', :release_type,
      'InstallDate', :installed_on
    ]

    HOTFIX_MAPPING = [
      'Fix Description', :description,   # Check Fix Decription, and then if
      'Comments',        :description2,  # not found, check Comments
      'Installed',       :installed,
      'Service Pack',    :service_pack,
      'Valid',           :valid,
    ]

    HOTFIX_MAPPING_VISTA = [
      'CurrentState',    :current_state,
      'Visibility',      :visibility,
      'InstallTimeHigh', :install_time_high,
      'InstallTimeLow',  :install_time_low
    ]

    def initialize(_c, fs)
      @patches = []
      @applications = []
      @patch_install_dates = {}
      @product_keys = {}

      reg_doc = initialize_registry_doc(fs)
      registry_applications(reg_doc, fs)
      registry_patches(reg_doc)
    end

    #     # Process application images
    #     e.find_each("./descendant::image") { |i| nh[:image_md5] = i.attributes['md5']; validate_image(i, nh)}
    #
    #     def self.validate_image(imageNode, nh)
    #       #logger.warn("MIQ(applications-add_elements): Checking application image [#{nh.inspect}] -- [#{imageNode.to_s}]")
    #       x = ApplicationImage.find_by_md5(imageNode.attributes['md5'])
    #       if x
    #         #logger.warn("MIQ(applications-add_elements): Application image     found [#{imageNode.attributes['md5']}]")
    #       else
    #         #logger.warn("MIQ(applications-add_elements): Application image NOT found [#{imageNode.attributes['md5']}]")
    #         ApplicationImage.create({:md5=>imageNode.attributes['md5'], :name=>nh['name'], :vendor=>nh['vendor'], :version=>nh['version']})
    #       end
    #     end

    def initialize_registry_doc(fs)
      regHnd = RemoteRegistry.new(fs, true)
      #     reg_doc = regHnd.loadHive("software", ["Microsoft"])
      reg_doc = regHnd.loadHive('software',
                                [{:key => 'Microsoft/Windows NT/CurrentVersion/Hotfix', :value => ['fix description', 'comments', 'installed', 'service pack', 'valid']},
                                 {:key => 'Microsoft/Windows/CurrentVersion/Installer/UserData', :value => ['DisplayName', 'Publisher', 'DisplayVersion', 'Comments', 'InstallLocation']},
                                 {:key => 'Microsoft/Windows/CurrentVersion/Uninstall', :value => ['DisplayName', 'Publisher', 'DisplayVersion', 'FileDescription', 'ReleaseType', 'InstallDate']},
                                 {:key => 'Wow6432Node/Microsoft/Windows/CurrentVersion/Uninstall', :value => ['DisplayName', 'Publisher', 'DisplayVersion', 'FileDescription', 'ReleaseType', 'InstallDate']},
                                 {:key => 'Microsoft/Windows/CurrentVersion/App Paths', :value => ['(Default)', 'FileDescription', 'CompanyName', 'ProductVersion', 'FileDescription', 'ProductName', 'lang', 'path']},
                                 {:key => 'Wow6432Node/Microsoft/Windows/CurrentVersion/App Paths', :value => ['(Default)', 'FileDescription', 'CompanyName', 'ProductVersion', 'FileDescription', 'ProductName', 'lang', 'path']},
                                 # These locations are used to check for Product keys
                                 {:key => 'Microsoft/Internet Explorer/Registration', :value => ['digitalproductid']},
                                 {:key => 'Microsoft/Windows/CurrentVersion/Component Based Servicing/Packages', :value => ['CurrentState', 'Visibility', 'InstallTimeHigh', 'InstallTimeLow']},
                                 {:key => 'Microsoft/Office', :value => ['digitalproductid']}])
      @digital_product_keys = regHnd.digitalProductKeys
      regHnd.close

      @product_keys = collectProductKeys(@digital_product_keys)
      reg_doc
    end

    def registry_applications(registry_doc, fs)
      # Get the applications
      reg_node = MIQRexml.findRegElement("HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Installer\\UserData", registry_doc.root)
      registry_applications_user_data(reg_node) if reg_node
      ["HKEY_LOCAL_MACHINE\\SOFTWARE\\Wow6432Node\\Microsoft\\Windows\\CurrentVersion\\App Paths",
       "HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\App Paths"].each do |reg_path|
        registry_applications_app_paths(registry_doc, reg_path, fs)
      end
      ["HKEY_LOCAL_MACHINE\\SOFTWARE\\Wow6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall",
       "HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall"].each do |reg_path|
        reg_node = MIQRexml.findRegElement(reg_path, registry_doc.root)
        reg_node&.each_element_with_attribute(:keyname) do |e|
          registry_applications_uninstall(e)
        end
      end
    end

    def registry_applications_user_data(reg_node)
      reg_node.each_element_with_attribute(:keyname) do |users|
        users.each_element_with_attribute(:keyname) do |components|
          next unless components.attributes[:keyname].downcase == "products"
          components.each_element_with_attribute(:keyname) do |products|
            add_applications(PRODUCTS_MAPPING, "win32_product", products)
          end
        end
      end
    end

    def registry_applications_app_paths(registry_doc, registry_path, fs)
      return unless (reg_node = MIQRexml.findRegElement(registry_path, registry_doc.root))
      postProcessApps(reg_node, fs)
      reg_node.each_element_with_attribute(:keyname) do |e|
        add_applications(APP_PATHS_MAPPING, "app_path", e)
      end
    end

    def add_applications(mapping, type_name, element)
      return if (attrs = XmlFind.decode(element, mapping))[:name].nil?
      attrs[:typename] = type_name; attrs[:product_key] = @product_keys[attrs[:name]]
      clean_up_path(attrs)
      @applications << attrs unless isDupApp?(attrs)
    end

    def registry_applications_uninstall(element)
      return if (attrs = XmlFind.decode(element, UNINSTALL_MAPPING))[:name].nil?
      if ["security update", "update"].include?(attrs.delete(:release_type).to_s.downcase)
        @patch_install_dates[e.attributes[:keyname]] = Time.parse.getlocal(attrs[:installed_on]) unless attrs[:installed_on].nil?
        return
      else
        attrs.delete(:installed_on)
      end
      attrs[:typename] = "uninstall"; attrs[:product_key] = @product_keys[attrs[:name]]
      @applications << attrs unless isDupApp?(attrs)
    end

    def registry_patches(registry_doc)
      # Get the patches (Win2000, Win2003, WinXP)
      reg_node = MIQRexml.findRegElement("HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Hotfix", registry_doc.root)
      reg_node&.each_element_with_attribute(:keyname) do |e|
        registry_patches_hotfixes(e)
      end
      # Get the patches (Vista, Win2008, Windows 7)
      reg_node = MIQRexml.findRegElement("HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Component Based Servicing\\Packages", registry_doc.root)
      hotfix = {}
      reg_node&.each_element do |e|
        registry_patches_packages(hotfix, e)
      end
    end

    def registry_patches_hotfixes(element)
      attrs = XmlFind.decode(element, HOTFIX_MAPPING)
      # Check both descriptions and take the first one with a value
      attrs.delete(:description2) if attrs[:description] || attrs[:description2].blank?
      attrs[:description] = attrs.delete(:description2) if attrs[:description2]

      attrs.merge!(:name => element.attributes[:keyname], :vendor => "Microsoft Corporation", :installed_on => @patch_install_dates[element.attributes[:keyname]]) unless element.attributes.nil? || element.attributes[:keyname].nil?
      @patches << attrs
    end

    def registry_patches_packages(hotfix, element)
      return if element.attributes.nil? || element.attributes[:keyname].nil?
      if element.attributes[:keyname][0, 8] == 'Package_'
        # don't add this package if the ID is nil
        return if (hotfix_id = hotfix_id(element)).nil?

        hotfix[hotfix_id] ||=
          begin
            attrs = XmlFind.decode(element, HOTFIX_MAPPING_VISTA)
            install_time = wtime2time(attrs[:install_time_high], attrs[:install_time_low])
            @patches << {:name => hotfix_id, :vendor => "Microsoft Corporation", :installed_on => install_time, :installed => 1}
            true
          end
      end
    end

    def hotfix_id(element)
      # Expected pattern: Package_for_KBxxx_RTM~xxxx
      # Get the hotfix id (KB #) out of the keyname
      package = element.attributes[:keyname].split("_")
      # If the package identifier starts with KB, use this
      # otherwise grab the ID from the end of the string (if it's long enough)
      if package[2][0, 2] == 'KB'
        hotfix_id = package[2]
      elsif package.size >= 4
        hotfix_id = package[3]
      else
        # Unknown package ID pattern, print this out
        str = ''
        element.write(str)
        $log.warn("Win32Software::initialize - Can't determine patch element's hotfix id: #{str}")
      end
      hotfix_id.split('~')[0] unless hotfix_id.nil?
    end

    def to_xml(doc = nil)
      doc ||= MiqXml.createDoc(nil)
      element_to_xml(doc, @applications, "applications", "application")
      element_to_xml(doc, @patches, "patches", "patch")
      doc
    end

    def element_to_xml(doc = nil, software_type, doc_element, node_element)
      doc ||= MiqXml.createDoc(nil)
      return doc if software_type.empty?
      node = doc.add_element(doc_element)
      software_type.each { |a| node.add_element(node_element, XmlHelpers.stringify_keys(a)) }
      doc
    end

    def isDupApp?(attrs)
      clean_up_path(attrs)
      @applications.each do |app|
        return true if app[:name] == attrs[:name]
      end
      false
    end

    def clean_up_path(attrs)
      if attrs[:path]
        ["\\", ";"].each { |c| attrs[:path].chomp!(c) }
        attrs[:path].gsub!(/^"/, "")
        attrs[:path].gsub!(/"$/, "")
      end
    end

    def self.DecodeProductKey(product_key)
      return if product_key.blank? || product_key.length < 67
      y = []; product_key.split(",")[52..67].each { |b| y << b.hex }
      return MIQEncode.base24Decode(y)
    rescue => err
      $log.error "MIQ(DecodeProductKey): [#{err}]"
    end

    private

    def postProcessApps(appPath, fs)
      # The icon sections below will need to be uncommented when we are ready to start
      # implementing application image uploading.
      # iconNode = MIQRexml.findElement("Applications/images", xmlCol.root)
      appPath.each_element do |app|
        app.each_element_with_attribute(:name, '(Default)') do |appNode|
          begin
            next if appNode.text.nil?
            # st = Time.now

            fileName = appNode.text
            fileName.tr!("\\", "/")
            fileName = fileName[1..-2] if fileName[0, 1] == "\"" && fileName[-1, 1] == "\""
            fileName = "C:/" + fileName if fileName[0..0] == "/"

            fh = fs.fileOpen(fileName)
            vi = PEheader.new(fh).versioninfo
            unless vi.length.zero?
              viNode = app.add_element(:versioninfo)
              vi.each_pair { |k, v| viNode.add_element(:value, {:name => k}).add_text(v.to_s) }
            end

            # Access application icons
            # peData = PEheader.new(fh)
            # if peData.icons.length > 0
            #  ie = e1.add_element("image",{"file"=>fileName, "count"=>peData.icons.length.to_s, "md5"=>Digest::MD5.hexdigest(peData.icons[0])})
            #  addIconData(ie, peData, iconNode)
            # end
          rescue Exception # => err
            # $log.debug "(Win32Software-postProcessApps) - file:[#{fileName}] - error:[#{err.to_s}]"
          ensure
            fh.close if fh
          end
        end
      end
    end

    def collectProductKeys(prodKeys)
      prodKeys.inject({}) do |pks, pk|
        # if e.parent && e.parent.attributes[:fqname] && e.parent.attributes[:fqname].downcase != 'software\\microsoft\\windows nt\\currentversion'
        reg_path = build_reg_path(pk)
        unless reg_path[-1].to_s.downcase == 'currentversion'
          pks[reg_path[-2]] = MiqWin32::Software.DecodeProductKey(pk.text)
        end
        pks
      end
    end

    def build_reg_path(node)
      path = []
      p = node.parent
      while p && p.name
        path << p.attributes[:keyname] if p.respond_to?(:attributes) # Skip document class
        p = p.parent
      end
      path.compact.reverse
    end

    def wtime2time(high_time, low_time)
      th = [high_time.to_i].pack('L').unpack('L')[0] << 32
      tl = [low_time.to_i].pack('L').unpack('L')[0]
      return nil if (time_int = ((th + tl) - 116444736000000000) / 10000000) < 0
      Time.at(time_int).getutc rescue nil
    end
  end # Class Software
end # Module MiqWin32
