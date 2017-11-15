class RGC
  class DummyAdapter < Adapter
    attr_accessor :initialized

    def initialize!
      self.initialized = true
    end
  end
end
