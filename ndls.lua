-- endless and/or noodles

function r() norns.script.load(norns.script.state) end

--external libs
include 'ndls/lib/nest/core'
include 'ndls/lib/nest/norns'
include 'ndls/lib/nest/grid'
include 'ndls/lib/nest/arc'
include 'ndls/lib/nest/txt'
cartographer, Slice = include 'ndls/lib/cartographer/cartographer'
cs = require 'controlspec'

ndls = include 'ndls/lib/globals'               --shared values
mpats, mpat = include 'ndls/lib/metapattern'    --multi-scope wrapper around pattern_time
mparams, mparam = include 'ndls/lib/metaparam'  --multi-scope wrapper around params
sc, reg = include 'ndls/lib/softcut'            --softcut utilities
cr = include 'ndls/lib/crow'                    --crow utilities

for i = 1,8 do mpats[i] = mpat:new() end

local all = { 'zone', 'voice', 'global' }
local some = { 'zone', 'voice' }

--add params using the metaparams abstraction
mparams:add { 
    id = 'vol', 
    type = 'control', controlspec = cs.def { default = 1, max = 2 },
    scopes = all, scope = 'voice',
    action = function(i, v)
        sc.lvlmx[i].vol = v; sc.lvlmx:update(i)
    end
}
mparams:add {
    id = 'old', 
    type = 'control', controlspec = cs.def { default = 0.8, max = 1 },
    scopes = all, scope = 'global',
    action = function(i, v)
        sc.oldmx[i].old = v; sc.oldmx:update(i)
    end
}
mparams:add {
    id = 'pan', 
    type = 'control', controlspec = cs.def { min = -1, max = 1, default = 0 },
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
mparams:add {
    id = 'bnd', 
    type = 'control', controlspec = cs.def { min = -1, max = 1, default = 0 },
    scopes = all, scope = 'voice',
    action = function(i, v) sc.ratemx[i].bnd = v; sc.ratemx:update(i) end
}
mparams:add {
    id = 'cut',
    type = 'control', controlspec = cs.def { default = 1, quantum = 1/100/2, step = 0 },
    scopes = all, scope = 'zone',
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
mparams:add {
    id = 'q',
    type = 'control', controlspec = cs.def { default = 0.4 }, scopes = all, scope = 'voice',
    action = function(i, v)
        softcut.post_filter_rq(i, util.linexp(0, 1, 0.01, 20, 1 - v))
    end
}
local types = { 'dry', 'lp', 'hp', 'bp' } 
mparams:add {
    id = 'type', 
    type = 'option', options = types, scopes = all, scope = 'voice',
    action = function(i, v)
        for _,k in pairs(types) do softcut['post_filter_'..k](i, 0) end
        softcut['post_filter_'..types[v]](i, 1)
    end
}
mparams:add {
    id = 'aliasing', 
    type = 'control', controlspec = cs.new(), scopes = all, scope = 'global',
    action = function(i, v)
        sc.aliasmx[i].aliasing = v; sc.aliasmx:update(i)
    end
}
mparams:add {
    id = 'volt', 
    type = 'control', controlspec = cs.def { min = -5, max = 5 }, scopes = all, scope = 'zone',
    action = function(i, v)
        cr.outmx[i] = v; cr.outmx:update(i)
    end
}
mparams:add {
    id = 'alias', 
    type = 'binary', behavior = 'toggle', scopes = { 'voice' },
    action = function(i, v)
        sc.aliasmx[i].aliasing = v; sc.aliasmx:update(i)
    end
}
--  record & play flags only for when the loop in current zone is recorded
--      when not recorded, bind punch_in toggle for zone (0 for play)
--      when not playing, bind rec to punch in toggle
--      will need second param for mapping rec
mparams:add {
    id = 'rec',
    type = 'binary', behavior = 'toggle', scopes = { 'voice' }, hidden = true,
    action = function(i, v) sc.oldmx[i].rec = v; sc.oldmx:update(i) end
}
mparams:add {
    id = 'play',
    type = 'binary', behavior = 'toggle', scopes = some, scope = 'voice',
    action = function(i, v) 
        --sc.punch_in[z].play = v; sc.punch_in:update_play(z)
        sc.lvlmx[i].play = v; sc.lvlmx:update(i)
    end
}
local rate = mparams:add {
    id = 'rate',
    type = 'number', min = -7, max = 2, default = 0, scopes = some, scope = 'zone',
    action = function(i, v) sc.ratemx[i].oct = v; sc.ratemx:update(i) end
}
local rev = mparams:add {
    id = 'rev',
    type = 'binary', behavior = 'toggle', scopes = some, scope = 'zone',
    no_scope_param = true,
    action = function(i, v) sc.ratemx[i].dir = v>0 and -1 or 1; sc.ratemx:update(i) end
}
local td = mparams:add {
    id = 'tape/disk',
    type = 'binary', behavior = 'toggle', scopes = some, scope = 'zone',
    no_scope_param = true,
    action = function(i, v) end
}
function rate:set_scope(scope)
    mparam.set_scope(self, scope)
    rev:set_scope(scope)
    td:set_scope(scope)
end
mparams:add {
    id = 'send',
    type = 'binary', behavior = 'toggle', scopes = { 'voice' }, default = 1,
    action = function(i, v) sc.sendmx[i].send = v; sc.sendmx:update() end
}
mparams:add {
    id = 'return',
    type = 'binary', behavior = 'toggle', scopes = { 'voice' },
    action = function(i, v) sc.sendmx[i].ret = v; sc.sendmx:update() end
}

--add metaparam params
params:add_separator('config')
mparams:add_scope_params('scopes')

params:add_separator('ndls')
mparams:add_params()

local zone = ndls.zone

grid_ = {}

--128 grid interface
grid_[128] = function(varibright)
    local shaded = varibright and { 4, 15 } or { 0, 15 }
    local mid = varibright and 4 or 15

    return nest_ {
        voice = nest_(4):each(function(n) 
            local top, bottom = n, n + 4
            return nest_ {
                rec = _grid.toggle {
                    x = 1, y = bottom, 
                    value = function(s) 
                        local z = ndls.zone[n]
                        if not sc.punch_in[z].recorded then 
                            return sc.punch_in:get(z) --wrong state
                            --TODO set rec flag here instead of in punch_in
                        else return mparams.id['rec']:get(n) end
                    end,
                    action = function(s, v) 
                        local z = ndls.zone[n]
                        
                        if not sc.punch_in[z].recorded then
                            if v == 1 then sc.punch_in:set(z, 1)
                            else 
                                sc.punch_in:set(z, 0)
                                mparams.id['play']:set(1, n)
                            end
                        else
                            if sc.punch_in[z].play == 0 and v == 1 then
                                sc.punch_in:clear(z)
                                sc.punch_in:set(z, 1)
                            else mparams.id['rec']:set(v, n) end
                        end
                    end
                },
                play = _grid.toggle {
                    x = 2, y = bottom, lvl = shaded,
                    value = function(s) 
                        local z = ndls.zone[n]
                        if not sc.punch_in[z].recorded then return 0
                        else return mparams.id['play']:get(n) end
                    end,
                    action = function(s, v) 
                        --TODO tape stop/start slew for t > ?
                        local z = ndls.zone[n]

                        if not sc.punch_in[z].recorded then
                            if v == 1 then 
                                sc.punch_in:set(z, 0)
                                mparams.id['rec']:set(1, n)
                            end
                        else mparams.id['play']:set(v, n) end
                    end
                },
                tap = _grid.trigger {
                    x = 3, y = bottom, selected = 1,
                    lvl = function() 
                        return sc.punch_in[ndls.zone[n]].tap_blink*11 + 4 
                    end,
                    action = function(s, v, t, dt) 
                        --TODO if not recorded then punch_in:manual() end
                        sc.punch_in:tap(ndls.zone[n], dt) 
                    end
                },
                alias = _grid.toggle {
                    x = 4, y = bottom,
                } :bind(mparams.id['alias'], n),
                send = _grid.toggle {
                    x = 5, y = bottom, lvl = shaded,
                } :bind(mparams.id['send'], n),
                ret = _grid.toggle {
                    x = 6, y = bottom, lvl = shaded,
                } :bind(mparams.id['return'], n),
                zone = _grid.number {
                    x = { 7, 15 }, y = bottom, fingers = { 1, 1 },
                } :bind(zone, n),
                copy = _grid.trigger {
                    x = { 7, 15 }, y = bottom, z = 2, fingers = { 2, 5 }, edge = 'falling',
                    lvl = { 0,
                        function(s, draw)
                            draw(mid); clock.sleep(0.1)
                            draw(0); clock.sleep(0.1)
                            draw(mid); clock.sleep(0.1)
                            draw(0)
                        end
                    },
                    action = function(s, v, t, d, add, _, list)
                        --TODO
                        --if #list > 2 then ndls.copy(src, dst, true)
                        --else ndls.copy(src, dst) end
                    end
                },
                tape_disk = _grid.toggle {
                    x = 5, y = top,
                } :bind(mparams.id['tape/disk'], n),
                rev = _grid.toggle {
                    x = 6, y = top, edge = 'falling', lvl = shaded,
                    value = function() return mparams.id.rev:get(n) end,
                    action = function(s, v, t)
                        --sc.slewmx:update(n, t)
                        --might want lower limit on slew
                        mparams.id.rev:set(v, n)
                    end
                },
                rate = _grid.number {
                    x = { 7, 15 }, y = top,
                    value = function() return mparams.id.rate:get(n) + 8 end,
                    action = function(s, v, t)
                        --sc.slewmx:update(n, t)
                        mparams.id.rate:set(v - 8, n)
                    end
                },
                --[[
                phase = _grid.affordance {
                    x = { 7, 15 }, y = top, z = -1,
                    --value = function() return math.floor(sc.phase[n].rel * ndls.zones) end,
                    redraw = function(s, v, g)
                        --TODO if not recorded then lvl = 0 
                        g:led(s.x[1] + math.ceil(sc.phase[n].rel * (s.x[2] - s.x[1])), s.y, 4)

                        --return true --return a dirty flag to redraw every frame
                    end
                }
                --]]
            }
        end)
    }
end

--putting it all together
ndls_ = nest_ {
    grid = grid_[128](true):connect { g = grid.connect() }
}

function init()
    sc.setup()
    mparams:bang()
    ndls_:init()
    ndls.zone:init()
end
