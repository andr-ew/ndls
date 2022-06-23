# ndls

4-track asyncronous tape looper, delay, loop splicer. pattern memory, performace oriented + configurable. and it's ~ bendy ~

spiritual successor to [anachronism](https://github.com/andr-ew/prosody#anachronsim)

## hardware

**required**
- norns
- grid (128, 64, 256, or midigrid)

**also supported**
- arc
- midi footswitch

## documentation

### grid

![documentation image](lib/doc/ndls_128.png)

- **rec:** press the rec key to create a new loop, then press it again to stop recording & begin playback. pressing rec while a loop is playing engages overdub. the **old** control sets the overdub level.
- **play:** play toggles track playback. to clear a loop, just toggle playback off, then record a new loop with the **rec** key as before.
- **buffer:** select which audio buffer (1-4) to record & play back from. multiple tracks can share the same buffer.
- **screen focus:** select which track controls to edit on the norns screen
- **arc focus:** select which track controls to edit on arc. 
  - by default, arc will display four different controls in one track. press any two keys in the same column of the arc focus component to flip orientation, editing four of the same control in different tracks
- **send & return:** these keys allow you to route the output of a track into the input of another track. all tracks with a lit **send** key will be routed into each track with a lit **return** key.
  - idea: send a loop track into another track set up like a delay, for echoed loops.

### norns
- **E1:** page
- **pages**
  - **v:** 
    - **E2:** vol, **E3:** old
    - **K2-K3:** randomize
  - **s:** 
    - **E2:** slice start, **E3:** slice length
    - **K2-K3:** randomize 
  - **f:** 
    - **E2:** filter cutoff, **E3:** filter resonance
    - **K2:** randomize cutoff, **K3:** filter type
  - **p:** 
    - **E2:** pan, **E3:** pitch bend
    - **K2:** randomize octave, **K3:** randomize pan


