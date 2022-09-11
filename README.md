# ndls (0.2.0-beta)

4-track, grid-based, asynchronous tape looper, delay, & sampler based on softcut. modeless, gesture looping, & performance-minded. highly bendy.

a spiritual successor to [anachronism](https://github.com/andr-ew/prosody#anachronsim), [anaphora](https://github.com/andr-ew/prosody#anaphora), and several unreleased precursors.

currently in beta - any & all feedback is highly appreciated! feel free to create an issue here or send me an email andrewcshike@gmail.com :) (email is usually the best way to reach me). if you're running into trouble, be sure to check out the [issues](https://github.com/andr-ew/ndls/issues) section to see if your issue has already been logged ~
## hardware

**required**

- [norns](https://github.com/p3r7/awesome-monome-norns) (220321 or later)
- [grid](https://monome.org/docs/grid/) (128, 64, 256, or midigrid)

**also supported**

- arc
- midi mapping

## install

in the maiden REPL, type `;install https://github.com/andr-ew/ndls`

## documentation

### quick start

### grid

![grid & arc documentation image](lib/doc/ndls_128.png)

the grid is split in two halves with two blocks of controls mapped to four tracks of softcut. rows 1-4 control tracks 1-4, rows 5-8 also control tracks 1-4.

see [here](lib/doc/alternate_grid_sizes.md) for alternate grid layouts (64, midigrid, 256)

#### bottom half

- **rec** toggle record & playback states, loop pedal style.
- **buffer:** select which audio buffer (1-4) to record & play back from. multiple tracks can share the same buffer.
- **slice:** each audio buffer has 7 independent playback windows that you switch between on the fly using the grid. each window has it's own editable **st** & **len** settings. slices 2-7 are auto-randomized upon recording a new loop into a buffer.
- **send & return:** these keys allow you to route the output of a track into the input of another track. all tracks with a lit **send** key will be routed into each track with a lit **return** key.
  - idea: send a loop track into another track set up like a delay, for echoed loops.

#### top half

- **norns/arc view:** set the track + page displayed on norns + arc. track selection on the y axis, page selection on the x axis.
- **rev:** set record/playback direction. hold & release to glide to the new direction.
- **rate:** record & playback rate, quantized to octaves.
  - press one key with one finger to jump instantly to a new pitch.
  - to ~ glide ~ smoothly to a new pitch, do this:
    - 1 - hold one finger on the lit / current value key
    - 2 - press the key of the rate you'd like to glide to
    - 3 - softcut will glide to the new rate, based on the amount of time you were holding down the lit key. this is an expressive gesture !

#### pattern recorders

the rightmost column contans 8 pattern recorders, these can record & play back any combination of input on grid, norns, or arc. use them like this:

- single tap
  - (blank pattern): begin recording
  - (recording pattern): end recording, begin looping
  - (playing pattern): play/pause playback
- double tap: overdub pattern
- hold: clear pattern

### norns + arc

#### MIX

![norns screen page MIX documentation image](lib/doc/ndls_MIX.png)

- **E2:** track output level
- **E3:** volume of old material when overdubbing (i.e. obverdub level/feedback level)

#### WINDOW

![norns screen page WINDOW documentation image](lib/doc/ndls_WINDOW.png)

- **E2:** slice window start point
- **E3:** slice window start length
- **K2:** randomize start point
- **K3:** randomize length
- **K2 + K3:** random window

randomization ranges can be configured in the params menu under **config > randomization**

#### FILTER

![norns screen page FILTER documentation image](lib/doc/ndls_FILTER.png)

- **E2:** filter cutoff
- **E3:** filter resonance

#### LFO

![norns screen page LFO documentation image](lib/doc/ndls_LFO.png)

- **E2:** pan
- **E3:** pitch bend (-1 to +1 octave)

### advanced settings

#### metaparams

(diagram)

#### metaparam options

(coming soon)
