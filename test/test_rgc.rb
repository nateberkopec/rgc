require "rgc"
require "minitest/autorun"

class TestRGC < Minitest::Test
  def setup
    @rgc = RGC.new(
      mission_name: "RGC Test",
      adapter: { name: :dummy }
    )
  end

  def test_mission_name
    assert_equal "RGC Test", @rgc.mission_name
  end

  def test_adapter
    assert_instance_of RGC::DummyAdapter, @rgc.adapter
    assert @rgc.adapter.initialized
  end
end
