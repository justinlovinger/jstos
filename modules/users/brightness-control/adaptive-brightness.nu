#!/usr/bin/env nu

def main [
  --min: int = 0 # Minimum brightness
  --max: int = 100 # Maximum brightness
  --knee: int = 100000 # Lux at max brightness. Affects how sensitive brightness is to lux.
  --interval: duration = 5sec # How often to check lux
  --threshold: int = 5 # Brightness must be at least this different to change
  --transition-time: duration = 1sec # How smoothly to transition brightness
] {
  # Ideally,
  # we would use `ClaimLight` and `ReleaseLight` ourselves,
  # but `busctl` provides no proper interface.
  # `busctl call --system net.hadess.SensorProxy /net/hadess/SensorProxy net.hadess.SensorProxy ClaimLight`
  # does not hold a claim
  # because the dbus connection ends
  # after the call returns.
  job spawn { monitor-sensor --light | ignore }

  let range = ($max - $min)
  mut brightness = (brillo -G | into float)
  mut change_brightness_id: oneof<nothing,int> = null;
  loop {
    let lux = (busctl get-property --system net.hadess.SensorProxy /net/hadess/SensorProxy net.hadess.SensorProxy LightLevel | split row ' ' | get 1 | into float)
    let new_brightness = ($min + $range * ([($lux + 1 | math log $knee), 1] | math min))
    if ($new_brightness - $brightness | math abs) > $threshold {
      $brightness = $new_brightness
      try { job kill $change_brightness_id }
      $change_brightness_id = job spawn { brillo -S $new_brightness -u ($transition_time | format duration µs) }
    }
    sleep $interval
  }
}
