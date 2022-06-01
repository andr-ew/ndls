# ndls

4-track asyncronous tape looper, delay, loop sampler. pattern memory & performace oriented. and it's ~ bendy ~

spititual successor to anachronism.

## hardware

**required**
- norns
- grid (128, 64, or midigrid)

**also supported**
- arc
- midi footswitch

## grid

![documentation image](doc/ndls.png)

## norns

**mixer view**
- **E1:** crossfader
- **E2-E3:** mix parameter
  - level
  - pan
- **K2:** track focus 1+2 / 3+4
- **K3:** parameter select

**track view**
- **E1:** page
- **E2-E3:** track parameter
  - **pages**
    - **v:** vol, old
    - **s:** start, length
    - **f:** filter tone, filter amount
    - **p:** pitch, pan
- **K2-K3:** randomize parameter
- **K1:** edit all

## notes

arc assignable to any of the track view parameters

scope
- track
  - values never reset, are saved across sessions in params
- buffer
  - value is unique per-buffer, per-track 
  - values reset when entering a new buffer 
    - when entering a blank buffer, volume resets to 1. when entering a recorded buffer, volume resets to 0.
- zone
  - value is unique per-zone, per-buffer, per-track
  - values for all zones reset when entering a new buffer

scoped UI components are just duplicated for each zone/buffer, so if a pattern is recorded, only one component scope will be mapped to the pattern

idea: when output volume for track becomes 0, play state is always off
- this makes adding new sounds after a crossfade slightly easier

## future maybe

pattern + audio save/recall

rate intervals (toggle per each)
- octave
- fifth
- maj7
- min7

sync
- sync record/play actions, pattern recorders, quantize window edits
- unique sync setting per zone & pattern recorder ? 
  - map this setting to the grid when holding K1
  - allow copying synced audio to unsynced zone & vice-versa
