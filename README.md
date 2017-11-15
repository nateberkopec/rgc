# Ruby Guidance Computer (RGC)

A spacecraft computer for guidance, navigation and control, written in Ruby.

## Usage

Write a mission script with the following:

```ruby
require 'rgc'

rgc = RGC.new(adapter: { name: "KRPC" }, ip: "192.168.1.6")
loop { rgc.executive.main }
```

See the `saturn_v.rb` script for an example with jobs.

## Adapters

* **Kerbal Space Program**, via KRPC and KRPC-rb.

## TODO

* Actual tests.
* Write an example program that does more than just launch the spacecraft.
* Write an adapter for another program, such as Orbiter.
