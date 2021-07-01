-- ndls
--
-- -- - -- --- -  ---- -- - ---  -- - - ---
-- -- - --- - --- - -- - --- - - - - - ---
--  --- --- -- - ---- -- - - -- - --- -----
-- -   --- - -- -- -- - -   -- - -- --- --
--
-- endless and/or noodles
-- 
-- version 0.1.0 @andrew
--

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
local types = { 'lp', 'bp', 'hp', 'dry' } 
mparams:add {
    id = 'type', 
    type = 'option', options = types, scopes = all, scope = 'zone',
    action = function(i, v)
        print(types[v], v)
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
mparams:add {
    id = 'rec',
    type = 'binary', behavior = 'toggle', scopes = { 'voice' }, hidden = true,
    persistent = false,
    action = function(n, v)
        sc.oldmx[n].rec = v; sc.oldmx:update(n) 

        local z = ndls.zone[n]
        if not sc.punch_in[z].recorded then
            sc.punch_in:set(z, v)
            if v==0 then mparams.id['play']:set(1, n) end
        elseif sc.lvlmx[n].play == 0 and v == 1 then
            --TODO reset mparams
            sc.punch_in:clear(z)
            sc.punch_in:set(z, 1)
        end
        
        arc_redraw()
    end
}
mparams:add {
    id = 'play',
    type = 'binary', behavior = 'toggle', scopes = some, scope = 'voice',
    action = function(n, v) 
        local z = ndls.zone[n]
        if v==1 and sc.punch_in[z].recording then
            sc.punch_in:set(z, 0)
        end 

        sc.lvlmx[n].play = v; sc.lvlmx:update(n)

        arc_redraw()
    end
}
local rate = mparams:add {
    id = 'rate',
    type = 'number', min = -7, max = 2, default = 0, scopes = some, scope = 'zone',
    action = function(i, v) 
        sc.ratemx[i].oct = v; sc.ratemx:update(i) end
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
local alt = false

--128 grid interface
grid_ = {}
grid_[128] = function(varibright, arc)
    local shaded = varibright and { 4, 15 } or { 0, 15 }
    local mid = varibright and 4 or 15
    local mid2 = varibright and 8 or 15

    local n_ = nest_ {
        voice = nest_(ndls.voices):each(function(n) 
            local top, bottom = n, n + 4
            return nest_ {
                rec = _grid.toggle {
                    x = 1, y = bottom, 
                } :bind(mparams.id['rec'], n),
                play = _grid.toggle {
                    x = 2, y = bottom, lvl = shaded,
                    value = function(s) 
                        if not sc.punch_in[ndls.zone[n]].recorded then return 0
                        else return mparams.id['play']:get(n) end
                    end,
                    action = function(s, v) 
                        --TODO tape stop/start slew for t > ?
                        
                        if sc.punch_in[ndls.zone[n]].recorded 
                            or sc.punch_in[ndls.zone[n]].recording 
                        then mparams.id['play']:set(v, n) end
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
                    x = 4, y = bottom, lvl = mid2,
                } :bind(mparams.id['alias'], n),
                send = _grid.toggle {
                    x = 5, y = bottom, lvl = shaded,
                } :bind(mparams.id['send'], n),
                ret = _grid.toggle {
                    x = 6, y = bottom,
                } :bind(mparams.id['return'], n),
                zone = _grid.number {
                    x = { 7, 15 }, y = bottom, 
                    --TODO if not tape/disk then sc.slew(0)
                } :bind(zone, n),
                copy = _grid.trigger {
                    x = { 7, 15 }, y = bottom, z = 2, fingers = { 2, 5 }, edge = 'falling',
                    enabled = false,
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
                    x = 5, y = top, lvl = mid2
                } :bind(mparams.id['tape/disk'], n),
                rev = _grid.toggle {
                    x = 6, y = top, edge = 'falling', lvl = shaded,
                    value = function() return mparams.id.rev:get(n) end,
                    action = function(s, v, t)
                        --TODO sc.slewmx:update(n, t)
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
            }
        end),
        --TODO support no arc & arc2
        view = arc and _grid.affordance {
            x = { 1, 4 }, y = { 1, 4 }, held = {}, vertical = false, lvl = 15,
            persistent = false,
            value = {
                { 0, 0, 0, 0 },
                { 1, 1, 1, 1 },
                { 0, 0, 0, 0 },
                { 0, 0, 0, 0 }
            },
            handler = function(s, x, y, z) 
                local dx, dy = x - s.x[1] + 1, y - s.y[1] + 1
                if z == 1 then
                    table.insert(s.held, { x = dx, y = dy })

                    if #s.held > 1 then
                        if s.held[1].x == s.held[2].x then s.vertical = true
                        elseif s.held[1].y == s.held[2].y then s.vertical = false end
                    end

                    for i = 1,4 do --y
                        for j = 1,4 do --x 
                            s.value[i][j] = (s.vertical and dx == j) and 1 or ((not s.vertical and dy == i) and 1 or 0)
                        end 
                    end
                    
                    return s.v
                else
                    for i,v in ipairs(s.held) do
                        if v.x == dx and v.y == dy then table.remove(s.held, i) end
                    end
                end
            end,
            redraw = function(s, v, g) 
                for i = 0,3 do for j = 0,3 do 
                    g:led(s.x[1] + j, s.y[1] + i, s.v[i + 1][j + 1] * s.lvl) 
                end end
            end,
            action = function() arc_redraw() end
        } or _grid.toggle {

        }
    }

    for n = 1,ndls.voices do
        --gotta add it down here for the z property to work :/
        n_.voice[n].phase = _grid.affordance {
            x = { 1, 16 }, y = n, z = 2,
            enabled = function() 
                return sc.lvlmx[n].play == 1 and sc.punch_in[ndls.zone[n]].recorded 
            end,
            redraw = function(s, v, g)
                --TODO consider showing play region phase
                g:led(s.x[1] + util.round(sc.phase[n].rel * (s.x[2] - s.x[1])), s.y, 8)

                return true --return a dirty flag to redraw every frame
            end
        }
    end
    return n_
end

--arc interface
arc_ = function(map)
    local rsens = 1/1000

    local _a = {
        vol = function(x, y)
            return _arc.number {
                sens = 0.25, max = 1.5, cycle = 1.5,
                enabled = function(s) return ndls_.grid.view.value[y][x] == 1 end,
                n = function(s) return tonumber(ndls_.grid.view.vertical and y or x) end,
            } :bind(mparams.id.vol, y)
        end,
        cut = function(x, y) 
            return nest_ {
                cut = _arc.affordance {
                    n = function(s) return tonumber(ndls_.grid.view.vertical and y or x) end,
                    sens = 0.25, x = { 42, 24+64 }, controlspec = cs.new(),
                    output = _output {
                        redraw = function(s, v, a)
                            local vv = math.floor(v*(s.x[2] - s.x[1])) + s.x[1]
                            local t = mparams.id.type:get(y)
                            for x = s.x[1], s.x[2] do
                                a:led(
                                    s.p_.n, 
                                    (x - 1) % 64 + 1, 
                                    t==1 and (               --lp
                                        (x < vv) and 4
                                        or (x == vv) and 15
                                        or 0
                                    )
                                    or t==2 and (            --bp
                                        util.clamp(
                                            15 - math.abs(x - vv)*3,
                                        0, 15)
                                    )
                                    or t==3 and (            --hp
                                        (x < vv) and 0
                                        or (x == vv) and 15
                                        or 4
                                    )
                                    or t==4 and 4            --dry
                                )
                            end
                        end
                    },
                    input = _arc.control.input {
                        enabled = function() return not alt end
                    },
                } :bind(mparams.id.cut, y),
                type = _arc.option {
                    n = function(s) return tonumber(ndls_.grid.view.vertical and y or x) end,
                    options = #types, sens = 1/32, --output = false,
                    x = { 27, 41 }, lvl = 12,
                    enabled = function() return alt end,
                    value = mparams.id.type:get(y),
                    action = function(s, v) 
                        mparams.id.type:set(v//1, y) 
                    end
                },
                enabled = function(s) return ndls_.grid.view.value[y][x] == 1 end
            }
        end,
        st = function(x, y)
            return nest_ {
                d = _arc.delta {
                    n = function() return tonumber(ndls_.grid.view.vertical and y or x) end,
                    output = _output(),
                    action = function(s, v)
                        if alt then reg.play:delta_start(y, v * rsens) 
                        else reg.play:delta_startend(y, v * rsens * 2) end
                    end
                },
                ph = _arc.affordance {
                    n = function() return tonumber(ndls_.grid.view.vertical and y or x) end,
                    x = { 33, 64+32 }, lvl = { 4, 15 }, input = false,
                    redraw = function(s, v, a)
                        local st = s.x[1] + math.ceil(
                            reg.play:get_start(y, 'fraction')*(s.x[2] - s.x[1] + 2)
                        )
                        local en = s.x[1] - 1 + math.ceil(
                            reg.play:get_end(y, 'fraction')*(s.x[2] - s.x[1] + 2)
                        )
                        local ph = s.x[1] + util.round(
                            sc.phase[y].rel * (s.x[2] - s.x[1])
                        )
                        local show = sc.lvlmx[y].play == 1 
                            and sc.punch_in[ndls.zone[y]].recorded
                        for x = st,en do
                            a:led(s.p_.n, (x - 1) % 64 + 1, s.lvl[(x==ph and show) and 2 or 1])
                        end
                        -- a:led(s.p_.n, (st - 1) % 64 + 1, s.lvl[2])
                        -- a:led(s.p_.n, (en - 1) % 64 + 1, s.lvl[2])

                        return true --return a dirty flag to redraw every frame
                    end
                },
                enabled = function(s) return ndls_.grid.view.value[y][x] == 1 end,
            }
        end,
        len = function(x, y)
            return nest_ {
                d = _arc.delta {
                    n = function() return tonumber(ndls_.grid.view.vertical and y or x) end,
                    output = _output(),
                    action = function(s, v)
                        if alt then reg.play:delta_start(y, v * rsens) 
                        else reg.play:delta_length(y, v * rsens) end
                    end
                },
                st = _arc.number {
                    n = function() return tonumber(ndls_.grid.view.vertical and y or x) end,
                    input = false, lvl = function() return alt and 15 or 4 end,
                    value = function() return reg.play:get_start(y, 'fraction') end
                },
                ['end'] = _arc.number {
                    n = function() return tonumber(ndls_.grid.view.vertical and y or x) end,
                    input = false, lvl = function() return alt and 4 or 15 end,
                    value = function() return reg.play:get_end(y, 'fraction') end
                },
                ph = _arc.affordance {
                    n = function() return tonumber(ndls_.grid.view.vertical and y or x) end,
                    x = { 33, 64+32 }, lvl = 4, input = false,
                    redraw = function(s, v, a)
                        a:led(s.p_.n, (
                            (
                                s.x[1] + util.round(
                                    sc.phase[y].rel * (s.x[2] - s.x[1])
                                )
                            ) - 1
                        ) % 64 + 1, s.lvl)

                        return true --return a dirty flag to redraw every frame
                    end,
                    enabled = function() 
                        return sc.lvlmx[y].play == 1 and sc.punch_in[ndls.zone[y]].recorded 
                    end,
                },
                enabled = function(s) return ndls_.grid.view.value[y][x] == 1 end,
            }
        end,
    }
    return nest_(ndls.voices):each(function(y) 
        return nest_(#map):each(function(x)
            return _a[map[x]] and _a[map[x]](x, y)
        end)
    end)
end

--screen interface
screen_ = nest_ {
    alt = _key.momentary {
        n = 1, action = function(s, v) 
            alt = v==1 
            arc_redraw()
        end
    }
}

--putting it all together
ndls_ = nest_ {
    grid = grid_[128](true, 4):connect({ g = grid.connect() }, 60),
    arc = arc_ { 'vol', 'cut', 'st', 'len' } :connect({ a = arc.connect() }, 60),
    screen = screen_:connect {
        key = key, enc = enc, screen = screen
    }
}

function init()
    sc.setup()
    ndls.zone:init()
    mparams:init()
    for i = 1,2 do mparams.id.rate:set(-1, i+2) end
    ndls_:init()
end
