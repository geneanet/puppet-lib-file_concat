## MONKEY PATCH PUPPET 3.8 file_concat support:
# https://github.com/elastic/puppet-logstash/issues/193
# https://tickets.puppetlabs.com/browse/MODULES-3310
if Puppet.version =~ /^3\.8\./
  puts "MONKEY PATCH for application/octet-stream support as network format (https://github.com/elastic/puppet-logstash/issues/193, https://tickets.puppetlabs.com/browse/MODULES-3310)"
  class Puppet::FileServing::Content
    def self.from_binary(content)
      instance = new("/this/is/a/fake/path")
      instance.content = content
      instance
    end
  end
  
  Puppet::Network::FormatHandler.create(:binary, :mime => "application/octet-stream", :weight => 1) do
    def intern_multiple(klass, text)
      raise NotImplementedError
    end
    
    def render_multiple(instances)
      raise NotImplementedError
    end
    
    # LAK:NOTE The format system isn't currently flexible enough to handle
    # what I need to support raw formats just for individual instances (rather
    # than both individual and collections), but we don't yet have enough data
    # to make a "correct" design.
    #   So, we hack it so it works for singular but fail if someone tries it
    # on plurals.
    def supported?(klass)
      true
    end
  end
end

Puppet::Type.type(:file_concat).provide(:ruby, :parent => Puppet::Type.type(:file).provider(:posix)) do

  def exists?
    resource.stat ? true : false
  end

  def create
    # FIXME security issue because the file won't necessarily
    # be created with the specified mode/owner/group if they
    # are specified
    send("content=", resource.should_content)
    resource.property_fix
  end

  def destroy
    File.unlink(resource[:path]) if exists?
  end

  def content
    actual = File.read(resource[:path]) rescue nil
    (actual == resource.should_content) ? resource.no_content : actual
  end
#
  def content=(value)
    File.open(resource[:path], 'w') do |fh|
      fh.print resource.should_content
    end
  end
end
