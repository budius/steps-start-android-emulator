#!/usr/bin/env ruby
require 'timeout'

# -----------------------
# --- Constants
# -----------------------

@adb = File.join(ENV['android_home'], 'platform-tools/adb')

# -----------------------
# --- Functions
# -----------------------

def log_fail(message)
  puts
  puts "\e[31m#{message}\e[0m"
  exit(1)
end

def log_warn(message)
  puts "\e[33m#{message}\e[0m"
end

def log_info(message)
  puts
  puts "\e[34m#{message}\e[0m"
end

def log_details(message)
  puts "  #{message}"
end

def log_done(message)
  puts "  \e[32m#{message}\e[0m"
end

def emulator_list
  devices = {}

  output = `#{@adb} devices 2>&1`.strip
  return {} unless output

  output_split = output.split("\n")
  return {} unless output_split

  output_split.each do |device|
    regex = /^(?<emulator>emulator-\d*)\s(?<state>.*)/
    match = device.match(regex)
    next unless match

    serial = match.captures[0]
    state = match.captures[1]

    devices[serial] = state
  end

  devices
end

def find_started_serial(running_devices)

  started_emulator = nil
  devices = emulator_list
  serials = devices.keys - running_devices.keys

  if serials.length == 1
    started_serial = serials[0]
    started_state = devices[serials[0]]
    if started_serial.to_s != '' && started_state.to_s != ''
      started_emulator = { started_serial => started_state }
    end
  end

  unless started_emulator.nil?
    started_emulator.each do |serial, state|
      return serial if state == 'device'
    end
  end

  nil
end

# -----------------------
# --- Main
# -----------------------

#
# Start adb-server
`#{@adb} start-server`

begin
  Timeout.timeout(800) do

    #
    # Check for started emulator serial
    serial = nil

    #
    # I understand what was going on with this "running_devices",
    # the script was trying to check who was running and
    # waiting for the extra one to get started.
    # But as we separate the script in two, that's not so possible anymore
    # A possible workaround would be to have some envman comma-separated value
    # with all the devices that were started by the bootup step(s)
    # and this step would wait for all of them to boot
    # while this would pretty and cover all use cases, it's outside my scope
    running_devices = {}
    serial = find_started_serial(running_devices)

    #
    # Wait for boot finish
    log_info("Waiting #{serial} emulator boot")

    boot_in_progress = true

    while boot_in_progress

      dev_boot = "#{@adb} -s #{serial} shell \"getprop dev.bootcomplete\""
      dev_boot_complete_out = `#{dev_boot}`.strip

      sys_boot = "#{@adb} -s #{serial} shell \"getprop sys.boot_completed\""
      sys_boot_complete_out = `#{sys_boot}`.strip

      boot_anim = "#{@adb} -s #{serial} shell \"getprop init.svc.bootanim\""
      boot_anim_out = `#{boot_anim}`.strip

      boot_in_progress = false if dev_boot_complete_out.eql?('1') && sys_boot_complete_out.eql?('1') && boot_anim_out.eql?('stopped')

      if boot_in_progress
        sleep 3
      end

    end

    `#{@adb} -s #{serial} shell input keyevent 82 &`
    `#{@adb} -s #{serial} shell input keyevent 1 &`

    `envman add --key BITRISE_EMULATOR_SERIAL --value #{serial}`

    log_done('Emulator is ready to use 🚀')
    exit(0)
  end
rescue Timeout::Error
  log_fail('Starting emulator timed out')
end
