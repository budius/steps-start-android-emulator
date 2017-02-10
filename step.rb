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

# -----------------------
# --- Main
# -----------------------


#
# Start adb-server
`#{@adb} start-server`

begin
  Timeout.timeout(800) do

    #
    # Wait for boot finish
    log_info("Waiting emulator boot")

    boot_in_progress = true

    while boot_in_progress

      dev_boot = "#{@adb} shell \"getprop dev.bootcomplete\""
      dev_boot_complete_out = `#{dev_boot}`.strip
      log_info("#{dev_boot} = #{dev_boot_complete_out}")

      sys_boot = "#{@adb} shell \"getprop sys.boot_completed\""
      sys_boot_complete_out = `#{sys_boot}`.strip
      log_info("#{sys_boot} = #{sys_boot_complete_out}")

      boot_anim = "#{@adb} shell \"getprop init.svc.bootanim\""
      boot_anim_out = `#{boot_anim}`.strip
      log_info("boot_anim = #{boot_anim_out}")

      boot_in_progress = false if dev_boot_complete_out.eql?('1') && sys_boot_complete_out.eql?('1') && boot_anim_out.eql?('stopped')

      if boot_in_progress
        log_info("sleeping...")
        sleep 3
      end

    end

    `#{@adb} shell input keyevent 82 &`
    `#{@adb} shell input keyevent 1 &`

    log_done('Emulator is ready to use')
    exit(0)
  end
rescue Timeout::Error
  log_fail('Starting emulator timed out')
end
