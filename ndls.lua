-- endless and/or noodles

--external libs
include 'ndls/lib/nest/core'
include 'ndls/lib/nest/grid'
include 'ndls/lib/nest/arc'
include 'ndls/lib/nest/txt'
cartographer, Slice = include 'ndls/lib/cartographer/cartographer'
cs = require 'controlspec'

ndls = include 'ndls/lib/globals'             --shared values
mp = include 'ndls/lib/metaparam'             --multi-scope wrapper around params
mpat, mpats = include 'ndls/lib/metapattern'  --multi-scope wrapper around pattern_time
sc, reg = include 'ndls/lib/softcut'          --softcut utilities
cr = include 'ndls/lib/crow'                  --crow utilities

for i = 1,8 do mpats[i] = mpat:new() end

--add params using the mp abstraction
--  mp: screen/arc
local all = { 'zone', 'voice', 'global' }
mp {
    id = 'vol', controlspec = cs.def { default = 1, max = 2 },
    scopes = all, scope = 'voice',
    action = function(i, v)
        sc.lvlmx[i].vol = v; sc.lvlmx:update(i)
    end
}
mp {
    type = 'control', id = 'old', controlspec = cs.def { default = 0.8, max = 1 },
    scopes = all, scope = 'global',
    action = function(i, v)
        sc.oldmx[i].old = v; sc.oldmx:update(i)
    end
}
mp {
    type = 'control', id = 'pan', controlspec = cs.def { min = -1, max = 1 },
    scopes = all, scope = 'global',
    action = function(i, v)
        sc.panmx[i].pan = v; sc.panmx:update(i)
    end,
    action_global = function(v)
        for i = 1, ndls.voices do
            local scl = ({ -1, 1, -0.5, 0.5 })[i]
            sc.panmx[i].pan = v * scl * 2; sc.panmx:update(i)
        end
    end
}
mp {
    type = 'control', id = 'bnd', controlspec = cs.def { min = -1, max = 1 },
    scopes = all, scope = 'voice',
    action = function(i, v)
        sc.ratemx[i].bnd = v; sc.ratemx:update(i)
    end
}
mp {
    type = 'control', id = 'cut',
    controlspec = cs.def { default = 1, quantum = 1/100/2, step = 0 },
    action = function(i, v) 
        softcut.post_filter_fc(i, util.linexp(0, 1, 20, 20000, v)) 
    end,
    action_global = function(v)
        for i = 1, ndls.voices do
            local scl = ({ -1, 1, -0.5, 0.5 })[i]
            softcut.post_filter_fc(i, util.linexp(0, 1, 20, 20000, 0.5 + (v * scl / 2))) 
        end
    end
}
mp {
    type = 'control', id = 'q',
    controlspec = cs.def { default = 0.4 },
    action = function(i, v)
        sc.post_filter_rq(i, util.linexp(0, 1, 0.01, 20, 1 - v))
    end
}
local types = { 'dry', 'lp', 'hp', 'bp' } 
mp {
    type = 'option', id = 'type', options = types,
    action = function(i, v)
        for _,k in pairs(types) do softcut['post_filter_'..k](i, 0) end
        softcut['post_filter_'..types[v]](i, 1)
    end
}
mp {
    type = 'control', id = 'aliasing', controlspec = cs.new(),
    scopes = all, scope = 'global',
    action = function(i, v)
        sc.aliasmx[i].aliasing = v; sc.aliasmx:update(i)
    end
}
mp {
    type = 'control', id = 'volt', controlspec = cs.new { min = -5, max = 5 },
    scopes = all, scope = 'zone',
    action = function(i, v)
        cr.outmx[i] = v; cr.outmx:update(i)
    end
}

--  mp: grid

--  mp: fixed

--TODO: nest_
