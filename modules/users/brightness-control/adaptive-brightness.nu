#!/usr/bin/env nu

def main [
  --min: int = 0 # Minimum brightness
  --max: int = 100 # Maximum brightness
  --knee: int = 100000 # Lux at max brightness. Affects how sensitive brightness is to lux.
  --step: float = 10.0 # Brightness is rounded to a multiple of this. This avoids changing brightness too often.
  --threshold: float = 0.4 # Threshold as percent of step. Brightness must be this much more of less than a step to change. This prevents brightness changing too often at step boundries.
  --interval: duration = 5sec # How often to check lux
  --smoothing: duration = 20sec # Smooth brightness over approximately this length of time. The higher the value, the slower brightness adjusts to changes in lux. Too low, and brightness may change rapidly as light shifts over the sensor.
  --transition-time: duration = 100ms # How smoothly to transition brightness
] {
  let range = ($max - $min)

  let smoothing = (2 / (($smoothing / $interval) + 1)) # Also known as `alpha` in exponential moving average

  let internal_step = ($step / $range)
  let internal_threshold = (($internal_step / 2) + $internal_step * $threshold)

  # Ideally,
  # we would use `ClaimLight` and `ReleaseLight` ourselves,
  # but `busctl` provides no proper interface.
  # `busctl call --system net.hadess.SensorProxy /net/hadess/SensorProxy net.hadess.SensorProxy ClaimLight`
  # does not hold a claim
  # because the dbus connection ends
  # after the call returns.
  job spawn { monitor-sensor --light | ignore }

  mut internal_brightness = (((brillo -G | into float) - $min) / $range)
  mut moving_internal_brightness = $internal_brightness
  mut change_brightness_id: oneof<nothing,int> = null;
  loop {
    $moving_internal_brightness = ($smoothing * (get_brightness $knee) + (1 - $smoothing) * $moving_internal_brightness)
    if $moving_internal_brightness < ($internal_brightness - $internal_threshold) or $moving_internal_brightness > ($internal_brightness + $internal_threshold) {
      $internal_brightness = ($internal_step * ($moving_internal_brightness / $internal_step | math round))
      try { job kill $change_brightness_id }
      let display_brightness = ($min + $range * $internal_brightness)
      $change_brightness_id = job spawn { brillo -S $display_brightness -u ($transition_time | format duration µs) }
    }
    sleep $interval
  }
}

def get_brightness [ knee: int ] {
  let lux = busctl get-property --system net.hadess.SensorProxy /net/hadess/SensorProxy net.hadess.SensorProxy LightLevel | split row ' ' | get 1 | into float
  [($lux + 1 | math log $knee), 1] | math min
}
