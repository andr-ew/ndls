# ndls

endless and/or noodles

![documentation image](doc/ndls.png)

## configurable multiple param scoping

global -> local -> zoned

**arc/screen params:** vol, old, pan, bnd, cut, q, type, fade, aliasing, volt

**grid params:** rate, rev, alias, rec, play, send, return, tape/disk

- params can only have one scope at a time?
- local+zoned show on the screen in track focus, one after another (visually tabbed in UI)
- except for old, vol, q, bnd, global params detune across voices
- everything except rate & play can be mapped to any arc encoder
- rate & play is fixed to the grid, regardless of scope. dir is linked to rate scope
- type is under cut alt, fade is under len alt
- fixed / non-metaparam
    - zone: st, len
    - local: play, alias, glide, send, return, tap, rec (all grid only, play/rec/alias has params)
    - global: input mixing
- text-based or params config ?
    - i'm leaning params system for config now bc there's a natural coupling of scoping/mapping & save state. so under the hood all three scopes would be available at once w/ the interfaces basically hidden/shown based on the configuration params
    - so we'll do a `meta_param` type that creates the params for all scopes at load & hides the params of inactive scopes. the `meta_param` also hooks up to the `meta_pattern`s.
- pattern recorders are scope-androgenous. internally every param has its own `pattern_time` and the grid keys are "macro" controls. by default params have a local scope - when recording zoned params only, the pattern will take on a zoned scope so different patterns may play back in different zones (the pattern is deep-copied into new zones, & thus may be cleared ot modified). when pattern recording the metazone or another global param, the param takes on a global scope. mixed scope recordings will alias up to the highest scope.
  - will need some kind of `meta_pattern` type that creates & switches between `pattern_time` instances depending on the assumed scope.

- `st` & `len` are special cases. in the zoned scope, values are shared across voices but unique per-zone. in the local scope, values are unique & fixed in separate slices. in the global scope all values are the same & share the first slice (with independent controls for st/len within the buffer).


## scope + mapping defaults:

```
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
