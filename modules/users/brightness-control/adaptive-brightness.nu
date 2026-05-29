#!/usr/bin/env nu

def main [
  --min: int = 0 # Minimum brightness
  --max: int = 100 # Maximum brightness
  --knee: int = 100000 # Lux at max brightness. Affects how sensitive brightness is to lux.
  --interval: duration = 1sec # How often to check lux
  --smoothing: float = 0.3 # Smoothing factor for exponential moving average. Lower is slower.
  --threshold: int = 5 # Brightness must be at least this different to change
  --transition-time: duration = 1sec # How smoothly to transition brightness
] {
  let range = ($max - $min)

  # Ideally,
  # we would use `ClaimLight` and `ReleaseLight` ourselves,
  # but `busctl` provides no proper interface.
  # `busctl call --system net.hadess.SensorProxy /net/hadess/SensorProxy net.hadess.SensorProxy ClaimLight`
  # does not hold a claim
  # because the dbus connection ends
  # after the call returns.
  job spawn { monitor-sensor --light | ignore }

  mut avg_brightness = (get_brightness $min $range $knee)
  mut cur_brightness = (brillo -G | into float)
  mut change_brightness_id: oneof<nothing,int> = null;
  loop {
    $avg_brightness = ($smoothing * (get_brightness $min $range $knee) + (1 - $smoothing) * $avg_brightness)
    let new_brightness = $avg_brightness
    if ($new_brightness - $cur_brightness | math abs) > $threshold {
      $cur_brightness = $new_brightness
      try { job kill $change_brightness_id }
      $change_brightness_id = job spawn { brillo -S $new_brightness -u ($transition_time | format duration µs) }
    }
    sleep $interval
  }
}

def get_brightness [
  min: int
  range: int
  knee: int
] {
  let lux = busctl get-property --system net.hadess.SensorProxy /net/hadess/SensorProxy net.hadess.SensorProxy LightLevel | split row ' ' | get 1 | into float
  ($min + $range * ([($lux + 1 | math log $knee), 1] | math min))
}
