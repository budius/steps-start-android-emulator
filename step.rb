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

def list_of_avd_images
  user_home_dir = ENV['HOME']
  return nil unless user_home_dir

  avd_path = File.join(user_home_dir, '.android', 'avd')
  return nil unless File.exist? avd_path

  images_paths = Dir[File.join(avd_path, '*.ini')]

  images_names = []
  images_paths.each do |image_path|
    ext = File.extname(image_path)
    file_name = File.basename(image_path, ext)
    images_names << file_name
  end

  return nil unless images_names
  images_names
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
# Input validation
emulator_name = ENV['emulator_name']
emulator_skin = ENV['skin']
emulator_options = ENV['emulator_options']

log_info('Configs:')
log_details("emulator_name: #{emulator_name}")
log_details("emulator_skin: #{emulator_skin}")
log_details("emulator_options: #{emulator_options}")

log_fail('Missing required input: emulator_name') if emulator_name.to_s == ''

avd_images = list_of_avd_images
if avd_images
  unless avd_images.include? emulator_name
    log_info "Available AVD images: #{avd_images}"
    log_fail "AVD image with name (#{emulator_name}) not found!"
  end
end

#
# Print running devices
running_devices = emulator_list
unless running_devices.empty?
  log_info('Running emulators:')
  running_devices.each do |device, _|
    log_details("* #{device}")
  end
end

#
# Start adb-server
`#{@adb} start-server`

#
# Start AVD image
os = `uname -s 2>&1`

emulator = File.join(ENV['android_home'], 'tools/emulator')
emulator = File.join(ENV['android_home'], 'tools/emulator64-arm') if os.include? 'Linux'

params = [emulator, '-avd', emulator_name]
params << "-skin #{emulator_skin}" unless emulator_skin.to_s.empty?
params << '-noskin' if emulator_skin.to_s.empty?

params << emulator_options unless emulator_options.to_s.empty?

command = params.join(' ')

log_info('Starting emulator')
log_details(command)

Thread.new do
  system(command)
end

#
# Check for started emulator serial
serial = nil
looking_for_serial = emulator_list.length == 0

while looking_for_serial
  sleep 1
  looking_for_serial = emulator_list.length == 0
end

log_done("Emulator started")

exit(0)
