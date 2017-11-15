require 'krpc'
require 'pry'

CLIENT_NAME = "RGC"
HOST_IP = "192.168.1.6"
$client = KRPC::Client.new(name: CLIENT_NAME, host: HOST_IP).connect!

vessel = $client.space_center.active_vessel
ctrl = vessel.control

binding.pry
