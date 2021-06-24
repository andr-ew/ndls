-- endless and/or noodles

--external libs
include 'ndls/lib/nest/core'
include 'ndls/lib/nest/grid'
include 'ndls/lib/nest/arc'
include 'ndls/lib/nest/txt'
cartographer = include 'ndls/lib/cartographer/cartographer'
cs = require 'controlspec'

ndls = include 'ndls/lib/globals'             --shared values
mp = include 'ndls/lib/metaparam'             --multi-scope wrapper around params
mpat, mpats = include 'ndls/lib/metapattern'  --multi-scope wrapper around pattern_time
sc, reg = include 'ndls/lib/softcut'          --softcut utilities

for i = 1,8 do mpats[i] = mpat:new() end

--add params using the mp abstraction

local all = { 'zone', 'voice', 'global' }
mp {
    id = 'vol', controlspec = cs.def { default = 1, max = 2 },
    scopes = all, scope = 'voice',
    action = function(i, v)
        sc.lvlmx[i].vol = v; sc.lvlmx:update(i)
    end
}

--TODO: nest_
