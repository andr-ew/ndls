# ndls

endless and/or noodles

---

## configurable multiple param scoping

global -> local -> zoned

voice params: vol, old, pan, bnd, cut, q, type, fade, rate, play, aliasing, volt

- params can only have one scope at a time?
- local+zoned show on the screen in track focus, one after another (visually tabbed in UI)
- except for old, vol, q, bnd, global params detune across voices
- everything except rate & play can be mapped to any arc encoder
- rate & play is fixed to the grid, regardless of scope. dir is linked to rate scope
- type is under cut alt, fade is under len alt
- fixed zone params: st, len
- fixed local params: alias, glide, send, return, tap, rec, channel (all grid only)
- fixed global params: input mixing
- text-based or params config ?

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
aliasing='global'
volt='zoned'

arc[1]='vol'
arc[2]='cut'
arc[3]='st'
arc[4]='len'

K1='old'

channel_sets_input=true
zones_share_loop_points=true

```

- i'm leaning params system now bc there's a natural coupling of scoping/mapping & save state. so under the hood all three scopes would be available at once w/ the interfaces basically hidden/shown based on the configuration params
