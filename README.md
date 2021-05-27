# ndls

endless and/or noodles

![documentation image](doc/ndls.png)

## configurable multiple param scoping

global -> local -> zoned

**arc/screen params:** vol, old, pan, bnd, cut, q, type, fade, play, aliasing, volt

**grid params:** rate, rev, alias, rec, play, send, return, tape/disk

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
aliasing='global'
bnd='local'
cut='zoned'
q='local'
type='zoned'
st='zoned'
len='zoned'
fade='local'
volt='zoned'

rate='zoned'
rev='zoned'
tape_disk='zoned'
rec='local'
play='local'
send='local'
return='local'
alias='local'

arc[1]='vol'
arc[2]='cut'
arc[3]='st'
arc[4]='len'

K1='old'
```

- i'm leaning params system now bc there's a natural coupling of scoping/mapping & save state. so under the hood all three scopes would be available at once w/ the interfaces basically hidden/shown based on the configuration params
- pattern recorders are scope-androgenous. internally every param has its own `pattern_time` and the grid keys are "macro" controls. by default params have a local scope - when recording zoned params only, the pattern will take on a zoned scope so different patterns may play back in different zones. when pattern recording the metazone or another global param, the param takes on a global scope. mixed scope recordings will alias up to the highest scope.
- `st` & `len` are special cases. in the zoned scope, values are shared across voices but unique per-zone. in the local scope, values are unique & fixed in separate slices. in the global scope values are still unique but they all share the same slice. 
