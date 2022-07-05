# ndls

4-track asyncronous tape looper, delay, loop splicer. pattern memory, performace oriented + configurable. and it's ~ bendy ~

(spiritual successor to [anachronism](https://github.com/andr-ew/prosody#anachronsim))

## hardware

**required**
- norns
- grid (128, 64, 256, or midigrid)

**also supported**
- arc
- midi footswitch

## grid

![documentation image](doc/ndls.png)

## norns

**track view**
- **E1:** page
- **E2-E3:** track parameter
  - **pages**
    - **v:** vol, old
      - **K2-K3:** randomize
    - **s:** start, length
      - **K2-K3:** randomize 
    - **f:** cutoff, resonance
      - **K2:** randomize cutoff
      - **K3:** filter type
    - **p:** pitch, pan
      - **K2:** randomize octave
      - **K3:** randomize pan
- **K1:** edit all

## notes

arc assignable to any of the track parameters

track parameter randomization
  - play with different random distributions (gaussian is probably fine) for certain parameters (/all parameters?)
  - provide some options for tuning averages & deviations (particularly for length)

control scopes
- track
  - values never reset, are saved across sessions in params
  - maybe disallow pattern recording ?
- buffer
  - value is unique per-buffer, per-track 
  - values reset when entering a new buffer 
    - when entering a blank buffer, volume resets to 1. when entering a recorded buffer, volume resets to 0.
  - patterns are cleared out on reset
- slice
  - value is unique per-slice, per-buffer, per-track
  - values for all slices reset when entering a new buffer
- random slice
  - slice, but values are automatically randomized upon filling a new buffer in all slices but the first slice
  - start & length are fixed in this scope

scoped UI components are just duplicated for each zone/buffer, so if a pattern is recorded, only one component scope will be mapped to the pattern

control object
- only creates a real param for the track scope, which will be saved in the pset
- for all other scopes, just store intentially volitile internal data for every buffer/zone

still not really sure whether zone slices within a buffer should be shared across tracks or unique
- leaning shared for now

slew options
- fixed slew (used for switching between zones)
- disable glide (use the fixed slew on the rate component)

edit all
- each control has an additional UI component that becomes visible (or foregrounded on arc/grid) when holding K1. these are track scope offsets to the scoped value which cannot be pattern recorded. useful for shifting a value after it has been pattern recorded, or altering the base value across slices.
  - a param is always made for the edit all value - so there's always a destination for midi mapping a control regardless of scope
  - for track scope controls, the edit all value is the same as the control value
  - for buffer scope & below, the edit all value is reset on script load
  - the state displayed by a control component is the local state summed with the edit all value
    - to accomplish this in tandem with pattern recording there will need to be separate components for input & output per control (and also separate input components per scope)
- for a non-recorded track/buffer - the edit all control is shown
- i need a better name for this than edit all lol
  - "track edit", "global edit" ?
- holding K1 could also reveal a second bank of 8 pattern recorders  ;)
- for st/len instead of an all edit control K1 shows window edit for buffer start & end points

page graphics
- v: mixer (track volumes)
- s: waveform
- f: filter graph
- p: mixer (track pans)

should probabaly switch to using decibels for vol

slew option for most controls (lua-side)
- allows for smooth changes between slices/presets
- I'm dubious of adding more complexity to the main UI & I'm not sure how helpful it would be as a params menu config, but might still be worth it

alternate pagination
- one 4x4 matrix for grid & arc. vertical selects track 1-4, horizontal selects control page (mwfd)
- use the saved space to move send & return up top + add two more slices/presets
- pages
  - m (mix)
    - norns: volume, pan
    - arc: volumes 1-4 (only page that maps arc across tracks. selected track is lit for clarity)
  - w (window)
    - norns: start, len
    - arc: volume, pan, start, len
  - f (filter)
    - norns: cut, q
    - arc: cut, q, start, len
  - d (delay)
    - norns: bnd, old
    - arc: bnd, old, start, len

OR pagination matrix with an lfo page 🤪 (mwfl)
- pages (alt)
  - m (mix)
    - E: old, volume, pan
    - K: x vol, x pan
    - arc: volumes 1-4 (only page that maps arc across tracks. selected track is lit for clarity)
  - w (window)
    - E: end, start, len
    - K: x start, x len
    - arc: volume, pan, start, len
  - f (filter)
    - E: q, response, cut
    - K: x response, x cut
    - arc: cut, q, start, len
  - l (lfo)
    - E: amt, rate, dest
    - K: x rate, x dest
    - arc: rate, amt, start, len
      - or: rate for all 4 lfos (i.e. cycles). it would look cool... so that seems like reason enough
- on 64 grid, keys just change the control page focus rather than randomize


## future maybe

sample loading

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
