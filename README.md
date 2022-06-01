# ndls

endless and/or noodles

4-track asyncronous tape looper, delay, loop sampler. pattern memory & performace oriented. and it's ~ bendy ~

## hardware

**required** norns + one or more of the following:
- midi footswitch
- grid (128, 64, or midigrid)

**encouraged**
- arc
- midi cc controller

## grid

![documentation image](doc/ndls.png)

## norns

**mixer**
- **E1:** crossfader
- **E2-E3:** mix parameter
  - level
  - pan
- **K2:** track focus 1+2 / 3+4
- **K3:** parameter select

**track focus**
- **E1:** page
- **E2-E3:** track parameter
- **K2-K3:** randomize parameter
- **parameter pages**
  - **v:** vol, old
  - **s:** start, length
  - **f:** filter tone, filter amount
  - **p:** pitch, pan

## notes

arc assignable to any of the "track focus" parameters

scope
- zone/track setting for every track parameter
- zone scope UI components are just duplicated for each zone, so if pattern recorded, only one component in one zone will be mapped to the pattern

# future maybe

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
