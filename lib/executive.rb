require 'forwardable'

class RGC
  class Executive
    attr_reader :waitlist, :core_set_table
    extend Forwardable
    def_delegators :@rgc, :client, :vessel, :ctrl, :adapter

    def initialize(rgc)
      @rgc = rgc
      @waitlist = Array.new(7) { { time: nil, job: nil } }
      @core_set_table = Array.new(6) { CoreSet.new(self) }

      # at_exit { dump_core_set_to_file }

      # if File.exists?("RGC_task_dump") && !File.zero?("RGC_task_dump")
      #   @core_set_table = Marshal.load(File.read("RGC_task_dump"))
      # end

      Thread.new do
        while true
          sleep 3
          abort "Night Watchman abort!" if $last_time_exec_ran <= Time.now - 3
        end
      end
    end

    def main
      $last_time_exec_ran = Time.now
      run_waitlist_tasks

      # Highest priority in first slot
      core_set_table.sort_by!(&:priority).reverse!
      core_set = core_set_table.first
      result = core_set.job.resume if core_set.priority > 0
      if result == :kill
        core_set.priority = 0
        core_set.mpac = {}
        core_set.job = nil
      end
    end

    def soft_reset!
      puts "SOFT RESET!"
      @core_set_table = Array.new(6) { CoreSet.new(self) }
      @waitlist = Array.new(7) { { time: nil, job: nil } }
    end

    def request_core_set_for(priority: 1, job:)
      available_set = core_set_table.find { |cs| cs.available? }
      soft_reset! unless available_set

      available_set.job = Fiber.new { job.new(available_set).run }
      available_set.priority = priority
    end

    # See AGC DELAYJOB
    def delay_job(job, time)
      job.priority = 0 - job.priority
      empty = waitlist.find { |task| task[:time] == nil }
      soft_reset! unless empty
      empty[:time] = time
      empty[:job] = Proc.new { job.priority = 0 - job.priority }
    end

    def run_waitlist_tasks
      waitlist.select { |task| task[:time] && task[:time] <= Time.now }.each do |task|
        task[:job].call
        task.keys.each { |k| task[k] = nil }
      end
    end

    def dump_core_set_to_file
      core_sets = core_set_table.map { |cs| [cs.job.class, cs.priority, cs.mpac] }
      File.open("agc_task_dump", 'w') do |file|
        file.write(Marshal.dump(core_sets))
      end
    end

    class CoreSet
      extend Forwardable
      def_delegators :executive, :vessel, :ctrl, :client, :adapter
      attr_accessor :mpac, :priority, :job, :executive

      def initialize(executive)
        @mpac = {}
        @priority = 0 # Priority
        @executive = executive
      end

      def available?
        @priority == 0
      end
    end

    class Job
      attr_reader :core_set
      extend Forwardable
      def_delegators :core_set, :mpac, :priority, :vessel, :ctrl, :executive,
                     :adapter, :client

      def initialize(core_set)
        @core_set = core_set
      end
    end
  end
end
