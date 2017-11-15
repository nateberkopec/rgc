require 'rgc'

rgc = RGC.new(adapter: { name: "KRPC" }, ip: "192.168.1.6")

class PreLaunchJob < RGC::Executive::Job
  def run
    until client.core.current_game_scene == :flight
      executive.delay_job(self, Time.now + 1)
      Fiber.yield
    end

    adapter.say "READY TO LAUNCH"

    ctrl.sas = true
    ctrl.throttle = 1

    vessel.auto_pilot.engage
    vessel.auto_pilot.target_pitch_and_heading(90, 90)

    mpac[:countdown] = 5

    until mpac[:countdown] == 0
      adapter.say mpac[:countdown], 1
      mpac[:countdown] -= 1
      executive.delay_job(core_set, Time.now + 1)
      Fiber.yield
    end

    executive.request_core_set_for(priority: 100, job: LaunchJob)
    Fiber.yield :kill
  end
end

class CoreSetPrinterJob < RGC::Executive::Job
  def run
    loop do
      puts ""
      puts executive.core_set_table.map { |cs| cs.priority }
      executive.delay_job(core_set, Time.now + 1)
      Fiber.yield
    end
  end
end

class LaunchJob < RGC::Executive::Job
  def run
    adapter.say "IGNITION!"
    ctrl.activate_next_stage # Ignition

    until vessel.thrust >= vessel.max_thrust * 0.6
      executive.delay_job(core_set, Time.now + 0.1)
      Fiber.yield
    end

    adapter.say "LIFTOFF!"

    ctrl.activate_next_stage
    executive.request_core_set_for(priority: 10, job: GravityTurnJob)
    executive.request_core_set_for(priority: 100, job: StagingJob)
    Fiber.yield :kill
  end
end

class GravityTurnJob < RGC::Executive::Job
  def run
    until vessel.flight(vessel.orbit.body.reference_frame).speed >= 100
      executive.delay_job(core_set, Time.now + 0.2)
      Fiber.yield
    end
    adapter.say "BEGINNING GRAVITY TURN"

    pitchover_angle = 84
    vessel.auto_pilot.target_pitch_and_heading(pitchover_angle, 90) # pitch *was* 90
    core_set.priority = 50

    executive.delay_job(core_set, Time.now + 15)
    Fiber.yield

    adapter.say "PITCH MANEUVER COMPLETED"

    #vessel.auto_pilot.pitch_pid_gains = [0,0,0]
    vessel.auto_pilot.disengage
    ctrl.sas = true
    sleep(0.5)
    ctrl.sas_mode = :prograde
    executive.request_core_set_for(priority: 10, job: ClosedLoopGuidanceJob)
    Fiber.yield :kill
  end
end

class StagingJob < RGC::Executive::Job
  def run
    engines = vessel.parts.engines.map { |e| [e, e.part.stage] }.each_with_object({}) do |i, sum|
      sum[i[1]] ||= []
      sum[i[1]] << i[0]
    end

    loop do
      if ctrl.current_stage == 11
        eject_interstage
        sleep(0.5)
        eject_escape
        engines[9] = engines[11]
      elsif engines[ctrl.current_stage]
        if engines[ctrl.current_stage].any? { |e| !e.has_fuel }
          # Fueled stage has run out
          vessel.control.activate_next_stage
        end
      else
        # Interstage fairing
        vessel.control.activate_next_stage
      end

      executive.delay_job(core_set, Time.now + 0.5)
      Fiber.yield
    end
  end

  def eject_interstage
    interstage = vessel.parts.all.select { |p| p.stage == 10 }.first
    interstage.modules.first.trigger_event("Decouple")
  end

  def eject_escape
    escape = vessel.parts.all.select { |p| p.stage == 9 }.first
    escape.modules[0].trigger_event("Activate Engine")
    escape.modules[1].trigger_event("Decouple")
  end
end

class ClosedLoopGuidanceJob < RGC::Executive::Job
  def run
    until ctrl.current_stage <= 11 && vessel.flight.dynamic_pressure <= 50
      executive.delay_job(core_set, Time.now + 2)
      Fiber.yield
    end

    vessel.auto_pilot.engage
    vessel.auto_pilot.pitch_pid_gains = [1, 1, 1] # Turn on pitch autopilot

    until vessel.orbit.periapsis_altitude >= 100_000
      percent_mission = vessel.met / 705
      vessel.auto_pilot.target_pitch_and_heading(
        linear_tangent_pitch(percent_mission),
        90
      )
      executive.delay_job(core_set, Time.now + 0.3)
      Fiber.yield
    end

    ctrl.throttle = 0
    vessel.parts.engines.last.active = false
    vessel.auto_pilot.disengage
    ctrl.sas = true
    sleep(1)
    ctrl.sas_mode = :prograde

    Fiber.yield :kill
  end

  def linear_tangent_pitch(fractional_time)
    initial_angle_in_rad = 5 * (Math::PI/ 180)
    final_angle_in_rad = 89 * (Math::PI/ 180)
    angle_in_rad = Math.atan(
      Math.tan(initial_angle_in_rad) -
        (Math.tan(initial_angle_in_rad) - Math.tan(final_angle_in_rad)) * fractional_time
    )
    (90 - (angle_in_rad * (180/Math::PI))) * 2
  end
end

rgc.executive.request_core_set_for(priority: 2, job: PreLaunchJob)
loop { rgc.executive.main }
