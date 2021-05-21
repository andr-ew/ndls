# ndls

endless and/or noodles

---

## configurable multiple param scoping

global -> local -> zoned

voice params: vol, old, pan, bnd, cut, q, type, st, len, fade, rate

- params can only have one scope at a time?
- local+zoned show on the screen in track focus, one after another (visually tabbed in UI)
- except for old, vol, q, bnd, global params detune across voices
- everything except rate can be mapped to any arc encoder
- rate is fixed to the grid, regardless of scope
- type is under cut alt, fade is under len alt
- probably a runtime config, so must be text based
  - alternatively hide/show could probably get us there,, which means config could be in the params menu  

```
--config.lua

vol='local'
old='global'
pan='global'
bnd='local'
cut='zoned'
q='local'
type='zoned'
st='zoned'
len='zoned'
fade='local'
rate='zoned'

arc[1]='vol'
arc[2]='cut'
arc[3]='st'
arc[4]='len'

K1='old'

channel_sets_input=true

```
