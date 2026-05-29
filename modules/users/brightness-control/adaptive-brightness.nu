#!/usr/bin/env nu

def main [
  --lux-function: oneof<closure,nothing> = null # `Fn() -> int`. A function that returns lux. Default attempts to get lux from an IIO device.
  --min: int = 0 # Minimum brightness
  --max: int = 100 # Maximum brightness
  --knee: int = 100000 # Lux at max brightness. Affects how sensitive brightness is to lux.
  --interval: duration = 5sec # How often to check lux
  --threshold: int = 5 # Brightness must be at least this different to change
  --transition-time: duration = 1sec # How smoothly to transition brightness
] {
  let lux_function = if $lux_function == null {
    (get_lux_function)
  } else {
    $lux_function
  }

  let range = ($max - $min)
  mut brightness = (brillo -G | into float)
  loop {
    let lux = (do $lux_function)
    let new_brightness = ($min + $range * ([($lux + 1 | math log $knee), 1] | math min))
    if ($new_brightness - $brightness | math abs) > $threshold {
      $brightness = $new_brightness
      job list | get id | each { try { job kill $in } }
      job spawn { brillo -S $new_brightness -u ($transition_time | format duration µs) }
    }
    sleep $interval
  }
}

def get_lux_function [] {
  let devices = (ls /sys/bus/iio/devices/iio:device* | get name)

  for device in $devices {
    let input_path = $"($device)/in_illuminance_input"
    if ($input_path | path exists) {
      return {|| open $input_path | into float }
    }

    let raw_path = $"($device)/in_illuminance_raw"
    if ($raw_path | path exists) {
      let offset_path = $"($device)/in_illuminance_offset"
      let offset = if ($offset_path | path exists) {
        open $offset_path | into float
      } else {
        0.0
      }

      let scale_path = $"($device)/in_illuminance_scale"
      let scale = if ($scale_path | path exists) {
        open $scale_path | into float
      } else {
        1.0
      }

      return {|| ((open $raw_path | into float)  + $offset) * $scale }
    }
  }

  error make -u {msg: "No IIO light sensor found"}
}
