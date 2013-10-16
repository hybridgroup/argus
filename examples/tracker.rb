require 'argus'

class FauxDrone
  def method_missing(*args)
    self
  end
end

class MovingAverage
  def initialize(size=20)
    @size = size
    @points = []
  end

  def <<(new_value)
    @points << new_value
    @points.shift if @points.size > @size
  end

  def value
    if @points.empty?
      0
    else
      sum = @points.inject(0.0) { |s, v| s+v }
      sum / @points.size
    end
  end
end

require 'base64'

class NavLogger
  def initialize(file_name)
    @file_name = file_name
    @file = open(file_name, "w")
  end

  def call(data)
    @file.write(Base64.encode64(data.raw))
  end

  def close
    @file.close
  end
end

class NavInfoDisplay
  def call(data)
    print "\033[0;0f"
    print "\033[2J"
    puts "Seq: #{data.sequence_number}"
    puts "  Vision flag: #{data.vision_flag}"
    puts "  Flying? #{data.flying?}"
    puts "  Com Lost? #{data.communication_lost?.inspect}"
    puts "  Watchdog Problem? #{data.com_watchdog_problem?.inspect}"
    puts "  Bootstrap: #{data.bootstrap?}"
    puts "  Command Ack: #{data.control_command_ack?}"

    puts "options...."
    data.options.each do |opt|
      display_option(opt)
    end
    puts
  end

  private

  def display_option(opt)
    puts opt.class.name
    if opt.is_a?(Argus::NavOptionDemo)
      printf "  State: %s (%d)\n", opt.control_state_name, opt.control_state
      printf "  Battery Level %d\n", opt.battery_level
      printf("  Pitch: %-8.2f  Roll: %-8.2f  Yaw: %-8.2f\n",
        opt.pitch, opt.roll, opt.yaw)
      printf("  Altitude: %08.2f\n", opt.altitude)
      printf("  Velocity: %0.2f, %0.2f, %0.2f\n",
        opt.vx, opt.vy, opt.vz)
    elsif opt.is_a?(Argus::NavOptionVisionDetect)
      puts "  Number detected: #{opt.detected_count}"

      if opt.detected_count > 0
        d = opt.detections.first
        printf("TYPE:%s/%s (%03d,%03d) %03dw %03dh @ %03dd Angle:%0.2f on %d\n",
          d.type, d.type_name, d.x, d.y, d.width, d.height, d.distance,
          d.orientation_angle, d.camera_source)
      end
    end
  end
end

class Tracker
  def initialize(drone)
    @drone = drone
    @led = nil
    @led_update = Time.now
    @done = false
    @dist_ave = MovingAverage.new(50)
    @x_ave = MovingAverage.new(20)
    @y_ave = MovingAverage.new(20)
  end

  def done
    @done = true
  end

  def call(data)
    return if @done
    data.options.each do |opt|
      if opt.is_a?(Argus::NavOptionVisionDetect)
        if opt.detected_count == 0
          drone.hover
        elsif opt.detected_count > 0
          d = opt.detections.first
          turn_movement = 0.0
          if d.x < 400
            drone.turn_left(0.2)
          elsif d.x > 600
            drone.turn_right(0.2)
          else
            drone.hover
          end
        end
      end
    end
  end

  private

  attr_reader :drone

  def target_aquired
    if @led != :aquired || led_time_out
      @led = :aquired
      @led_update = Time.now
      drone.controller.led(:green, 2.0, 3)
    end
  end

  def target_lost
    if @led != :lost || led_time_out
      @led = :lost
      @led_update = Time.now
      drone.controller.led(:red, 2.0, 3)
    end
  end

  def led_time_out
    (Time.now - @led_update) > 2.0
  end
end

drone = Argus::Drone.new

flying = ARGV.shift
if flying
  puts "Ready to fly?"
  gets
  cdrone = drone
else
  cdrone = FauxDrone.new
end

logger = NavLogger.new("navdata.raw64")
drone.nav_callback(logger)

drone.nav_callback(NavInfoDisplay.new)

tracker = Tracker.new(cdrone)
drone.nav_callback(tracker)

drone.start

drone.controller.enable_detection(2)

cdrone.take_off

while line = gets
  line.strip!
  break if line == ""
  drone.controller.led(line, 2.0, 4)
end

tracker.done
cdrone.hover
10.times do cdrone.land end
drone.stop

logger.close
