
<h1 align="center">NDLS (0.2.0-beta)</h1>

![ndls overview documentation image, labeled diagrams of the grid, norns screen, and arc. see rest of document for accesible text documentation](/lib/doc/ndls_overview.png)


4-track, grid-based, tape looper, delay, & sampler based on softcut. modeless, gesture looping, & performance-minded. highly bendy.

a spiritual successor to [anachronism](https://github.com/andr-ew/prosody#anachronsim), [anaphora](https://github.com/andr-ew/prosody#anaphora), and several unreleased precursors.

currently in beta - any & all feedback is highly appreciated! feel free to create an issue here or send me an email andrewcshike@gmail.com :) (email is usually the best way to reach me). if you're running into trouble, be sure to check out the [issues](https://github.com/andr-ew/ndls/issues) section to see if your issue has already been logged ~
## hardware

**required**

- [norns](https://github.com/p3r7/awesome-monome-norns) (220802 or later)
  - **the required norns version is recent, please be sure that your norns is up-to-date before launching**
- [grid](https://monome.org/docs/grid/) (128, 64, 256, or midigrid)

**also supported**

- arc
- midi mapping

## install

in the maiden REPL, type: 
```
;install https://github.com/andr-ew/ndls/releases/download/v0.2.0-beta/complete-source-code.zip
```

if you wish to install a different version, see the [releases](https://github.com/andr-ew/ndls/releases) tab

## start

recommended: luanch the script from the norns [SELECT](https://monome.org/docs/norns/play/#select) menu. 

those unable to access the SELECT menu can launch the script from the browser via the maiden REPL:
```
norns.script.load('/home/we/dust/code/ndls/ndls.lua')
```

## grid UI

![grid & arc documentation image. a labeled diagram of the grid. text descriptions below](lib/doc/ndls_128.png)

the grid is split in two halves with two blocks of [metaparams](#metaparams) mapped to four tracks of softcut. rows 1-4 control tracks 1-4, rows 5-8 also control tracks 1-4.

see [here](lib/doc/alternate_grid_sizes.md) for alternate grid layouts (64, midigrid, 256)

note: x & y ranges of each component in the 128 grid layout are labelled between the square brackets [] for those unable to view the daigrams in this document. if you need adjusted labels for 64 or 256 layout please email andrewcshike@gmail.com

### rec & play 
[x: 1-2, y: 5-6]

toggle record & playback states. these controls are interdependent. here are some ways to use them:
- record a new loop in a blank buffer:
  - 1 - toggle the **rec** key _on_
  - 2 - play some audio into softcut from TAPE or norns' inputs
  - 3 - toggle **rec** back _off_
  - 4 - softcut will loop what you just played, loop pedal style.
- overdub into a playing loop:
  - 1 - toggle the **rec** key _on_
  - 2 - play some new material into softcut from TAPE or norns' inputs
  - 3 - softcut will record the new material on top of the loop.
    - the volume of the old material is set by the **old** control.
- silence a playing loop:
  - toggle the **play** key _off_
- clear a buffer, and record a brand new loop:
  - 1 - toggle the **play** key _off_
  - 2 - toggle the **rec** key _on_. softcut will clear the old contents of the buffer.
  - 3 - play some new material into softcut from TAPE or norns' inputs
  - 4 - toggle **rec** back _off_
  - 5 - softcut will loop the new material
- use a blank buffer as a delay
  - 1 - toggle the **rec** key _on_
  - 2 - toggle the **play** key _on_
  - 3 - softcut will begin playing and overdubbing, like a delay.
    - delay time is set by time between key presses, as with looping. you can modify the delay time with the **len** or **rate** controls.
    - delay feeback is set by the **old** control

### track focus & page focus 
[track focus x: 1, y: 1-4; page focus x: 3-5, y: 1]

set the focus for the _norns screen & encoders_ (not grid). norns' controls are split into three pages: **MIX**, **TAPE**, and **FILTER**, and are editable intependently across four tracks, focused with **track focus**. 
- note that controls which have neither a white box nor underline are coupled to the same value across tracks, see [metaparams](#metaparams) for advanced info.

### rate: reverse & octave 
[reverse x: 7, y: 1-4; octave x: 8-14 ]

set the record _and playback_ direction and power-of-two rate multiple (AKA octave, or time division). the rate of change (or slew) for both these controls is touch-reactive. a single key tap will jump instantly to a new value, while hold-and-release gestures increase slew time in proportion to the held duration.
  - to glide to a new pitch with **rate: octave**:
    - 1 - hold one finger on the lit / current value key
    - 2 - press the key of the rate you'd like to glide to
    - 3 - softcut will glide to the new rate, based on the amount of time you were holding down the lit key.
  - to whip a 180 on **rate: reverse**:
    - hold reverse, and release
    - softcut will glide down to rate 0, then glide back up in the other direction, based on the amount of time you were holding down the key.

### buffer 
[ x: 3-6, y: 5-8 ]

select which audio buffer (1-4) to record & play back from. multiple tracks can share the same buffer, for multi-octave polyphonic looping & decoupled record & play head delay systems. lots of possibilities!
- idea: set two tracks to share the same buffer, and **send** one track to the other.

### preset 
[ x: 3-6, y: 7-13 ]

select a preset. there is 1 default preset + 6 unique, optionally randomized presets for any/all track controls. by default, only window parameters will be included in the preset. see [metaparams](#metaparams) for advanced info.

### loop 
[ x: 15, y: 1-4 ]

toggle looping on or off. disable for one-shot playback, triggered by the **preset** keys. turn ndls into a sampler!

### send & return 
[ send x: 14, y: 5-8; return x: 15, y: 5-8 ]

these keys allow you to **send** the output of a track into an invisibe audio bus & **return** them back into the input of another track. tracks with a lit **send** key will be routed into every track with a lit **return** key.
- idea: send a loop track into another track set up like a delay, for echoed loops.

### pattern recorders 
[ x: 16, y 1-8 ]

the rightmost column contans 8 pattern recorders, these can record & play back any combination of input on grid, norns, or arc. use them like this:

- single tap
  - (blank pattern): begin recording
  - (recording pattern): end recording, begin looping
  - (playing pattern): play/pause playback
- double tap: overdub pattern
- hold: clear pattern

## norns UI

across 3 pages, all 3 norns encoders are mapped to 9 [metaparams](#metaparams) for each track, with K2 & K3 mapped to randomizations of certain values. use the **track focus** + **page focus** components on the top left of the grid to switch between views. hold K1 on any page to assign [scopes](#metaparams). changes to any control can be pattern recorded using the grid.

### MIX

![norns MIX page documentation image. labelled image of the norns sreen. text descriptions below.](lib/doc/ndls_MIX.png)

#### E1: perserve/feedback level
the rate at which old material fades away. turn it up in a delay for long echo tails, or turn it down in a loop for tape decay memory loss.

#### E2: playback/output level
this level is summed with the **gain** param in the params menu to set the actual output level.

#### E3: stereo pan amount
this does not set the pan value directly, but rather, each track has a unique multiple that sets the pan value relative to the **spread** value. by default, in the global scope, spread will spread out all tracks evenly in the stereo feild, but you can switch the [scope](#metaparams) to track or preset to set pans independently, there will just be some uneven scaling between tracks.

#### K2: randomize level
hold to reset to 0db.

#### K3: randomize spread 
hold to reset to center.

### TAPE

![norns TAPE page documentation image. labelled image of the norns sreen. text descriptions below.](lib/doc/ndls_TAPE.png)

#### E1: perserve/feedback level
the rate at which old material fades away. turn it up in a delay for long echo tails, or turn it down in a loop for tape decay memory loss.

#### E2: playback/output level
this level is summed with the **gain** param in the params menu to set the actual output level.

#### E3: stereo pan amount
this does not set the pan value directly, but rather, each track has a unique multiple that sets the pan value relative to the **spread** value. by default, in the global scope, spread will spread out all tracks evenly in the stereo feild, but you can switch the [scope](#metaparams) to track or preset to set pans independently, there will just be some uneven scaling between tracks.

#### K2: randomize level
hold to reset to 0db.

#### K3: randomize spread 
hold to reset to center.


## arc UI

when arc is connected, the **arc focus** component will be visible to the right of **track focus**. the [norns](#norns) section above contains more info about the available [metaparams](#metaparams) (**vol**, **cut**, **st**, **len**). any changes to these controls can be pattern recorded using the grid.

### horizontal orientation

![arc documentation image](lib/doc/ndls_arc_horizontal.png)

by default, the arc will display four different metaparams from a single track – **vol**, **cut**, **st**, and **len**. press any **row** in the 4x4 grid with one finger to focus on another track.

### vertical orientation

![arc documentation image](lib/doc/ndls_arc_vertical.png)

to rotate to the **vertical** orientation, hold & release any two keys in the same **column** with two fingers. now, arc will display the same metaparam across all four tracks. press any **column** to focus on another metaparam ( **vol**, **cut**, **st**, or **len**).


## metaparams

(description)

### metaparam options

#### scope
#### randomization
#### initial preset values

## saving sessions

u can save & load full sessions via the PSET menu. saves all data, buffer audio, and patterns. yay! additionally, your last session is auto-saved to the "last session" pset every time you exit the app.

## roadmap

[read here](https://github.com/users/andr-ew/projects/3/views/1)
