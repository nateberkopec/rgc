require "adapter"
require "adapters/dummy"
require "adapters/krpc"
require "executive"

require "forwardable"

class RGC
  attr_accessor :mission_name, :adapter
  extend Forwardable
  def_delegators :adapter, :vessel, :ctrl, :client

  def initialize(opts = {})
    opts[:mission_name] ||= "RGC"
    self.mission_name = opts[:mission_name]
    adapter_class = opts[:adapter]&.[](:name) || "Dummy"
    adapter_class = RGC.const_get("#{adapter_class.capitalize}Adapter")
    self.adapter = adapter_class.new(opts)

    adapter.initialize!
  end

  def executive
    @executive ||= Executive.new(self)
  end
end
