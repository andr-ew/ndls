# ndls

endless and/or noodles

4-track asyncronous tape looper, delay, loop sampler. pattern memory & performace oriented. and it's ~ bendy ~

## hardware

**required** norns + one or more of the following:
- midi footswitch
- grid (128, 64, or midigrid)

**recommended**
- arc
- midi cc controller

## grid

![documentation image](doc/ndls.png)

## norns

mixer
- E1: crossfader
- E2-E3: mix parameter
  - level
  - pan
  - crossfader assign
- K2: track focus 1+2 / 3+4
- K3: parameter select

track focus
- K2-3: page
- pages
  - v
    - E1: pan
    - E2: vol
    - E3: old
  - s
    - E1: window
    - E2: start
    - E3: end
  - f
    - E1: tilt
    - E2: freq
    - E3: quality
  - p
    - E1: direction
    - E2: rate
    - E3: bend
  - z
    - E1: zone
    - E2: send
    - E3: return

## notes

arc assignable to first two pages of track parameters
- we can add more later

scope
- zone/track setting for every track parameter
- zone scope UI components are just duplicated for each zone, so if pattern recorded, only one component in one zone will be mapped to the pattern

# roadmap

sync
- sync record/play actions, pattern recorders, quantize window edits
- unique sync setting per zone & pattern ? 
  - map this setting to the grid when holding K1
  - allow copying synced audio to unsynced zone & vice-versa

engine selection
- softcut
- roughcut
  - supercollider engine with no resampling or interpolation
  - engine commands mimic most of the softcut API
  - additional parameters
    - bit depth
    - sample rate
    - sample rate slew
  - additional norns page (r)
    - E1: bit depth
    - E2: sample rate
    - E3: sample rate slew
  - glide/rate_slew is disabled (for a different feel)
