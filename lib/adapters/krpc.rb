require 'krpc'

class RGC
  class KrpcAdapter < Adapter
    attr_accessor :vessel, :ctrl, :client

    def initialize(opts)
      @client_name = opts[:mission_name]
      @ip = opts[:ip]
    end

    def initialize!
      @client = KRPC::Client.new(name: @client_name, host: @ip).connect!

      @vessel = @client.space_center.active_vessel
      @ctrl = vessel.control
    end

    def say(msg, length = 5)
      client.ui.message(msg, length)
      puts msg
    end
  end
end
