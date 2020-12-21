-- quad asyncronous tape looper for arc + grid in the style anaphora, anachronism, older things

--[[

REFACTOR

arc layout:

l s e p
l s e p
l s e p
l s e p

instead of the cycle / modulation stuff let's keep it simple and focus on pattern recording. modulation is more what wrlds is about. for the last ring position we can just go for a fine tune pitch control which should be fun

--]]

include 'lib/nest_/norns'
include 'lib/nest_/grid'
include 'lib/nest_/arc'
include 'lib/best_/txt'

sc = include 'lib/supercut'

local margin = 4
local gutter = 2
local width = 128 - (margin * 2)
local height = height - (margin * 2)


-- lets make a lib for this, just for heck !
local layout = {
    { 
        y = { margin, (height * 2 / 3) - gutter + margin }
        x = { 
            { margin,                            (width * 1 / 4) - gutter + margin },
            { (width * 1 / 4) + gutter + margin, (width * 2 / 4) - gutter + margin },
            { (width * 2 / 4) + gutter + margin, (width * 3 / 4) - gutter + margin },
            { (width * 2 / 4) + gutter + margin, (width * 4 / 4) + margin }
        },
    },
    {
        y = { (height * 2 / 3) + gutter + margin, (height * 3 / 3) + margin }
        x = {
            { margin,                            (width * 1 / 3) - gutter + margin },
            { (width * 1 / 4) + gutter + margin, (width * 2 / 3) - gutter + margin },
            { (width * 2 / 4) + gutter + margin, (width * 3 / 3) + margin }
        }
    }
}

local alt = function() return ndls.alt() == 1 end
local noalt = function() return ndls.alt() == 0 end

ndls = nest_:new {
    tp = nest_:new(1, 4):each(function(i)
        return {
            init = function(s) s.mod.tick:start() 
                metro.init(s.mod.tick, s.mod.dt):start()
            end,
            mod = {
                v = 0,
                x = 0,
                mu = 0,
                y = 0,
                dt = 1/60,
                tick = function()
                    local tp = ndls.tp[i]
                    local m = tp.mod
                    m.v = m.v - m.mu * m.dt
                    m.x = math.fmod(m.x + m.v * m.dt, 1)

                    tp.screen.pg.m.v(m.v)
                    tp.screen.pg.m.mu(m.mu)
                    tp.position(m.x)

                    local last = m.y
                    m.y = -1 * math.sin(m.x * 2 * math.pi)
                    local dy = m.y - last

                    for _,k in ipairs({ 'l', 'w', 'p', 'f' }) do 
                        tp.screen.pg[k]:modulate(dy)
                    end
                end
            },
            screen = {
                enabled = function() return not ndls.screen_global end,
                pager = _enc.txt.radio:new {
                    list = { 'm', 'l', 'w', 'p', 'f' },
                    v = 'p',
                    x = layout[2].x[1][1],
                    y = layout[2].y[1],
                    n = 1
                },
                pg = nest_:new {
                    -- onscreen visuals: marble falling through a tube, friction roates the tube between horizonatal & vertical
                    m = {
                        -- if .label == nil .label = .k
                        v = _enc.txt.number:new {
                            x = layout[2].x[2][1],
                            y = layout[2].y[1],
                            range = { -math.huge, math.huge },
                            action = function(s, v) ndls.tp[i].mod.v = v end,
                            n = 2
                        },
                        mu = _enc.txt.number:new {
                            label = utf8.char(956), --mu
                            face = 3, --
                            x = layout[2].x[3][1],
                            y = layout[2].y[1],
                            range = { -0.1, 1 },
                            action = function(s, v)
                              ndls.tp[i].mod.mu = v 
                              ndls.tp[i].mu(v)
                            end,
                            n = 3
                        }
                    },
                    l = {
                        modulate = function(s, d) 
                            s.lvl:delta(d * s.lmod())
                            s.pan:delta(d * s.pmod())
                        end,
                        lvl = _enc.txt.number:new {
                            label = 'd/w',
                            x = layout[2].x[2][1],
                            y = layout[2].y[1],
                            n = 2,
                            action = function(s, v) 
                                ndls.tp[i].level(v)

                                sc.level(i, v)
                            end,
                            enabled = noalt
                        },
                        pan = _enc.txt.number:new {
                            x = layout[2].x[3][1],
                            y = layout[2].y[1],
                            range = { -1, 1 },
                            n = 3,
                            action = function() 
                                sc.pan(i, v)
                            end,
                            enabled = noalt
                        },
                        lmod = _enc.txt.number:new {
                            label = 'mod',
                            x = layout[2].x[2][1],
                            y = layout[2].y[1],
                            n = 2,
                            enabled = alt
                        },
                        pmod = _enc.txt.number:new {
                            label = 'mod',
                            x = layout[2].x[3][1],
                            y = layout[2].y[1],
                            n = 3,
                            enabled = alt
                        }
                    },
                    w = {
                        modulate = function(s, d) 
                            s.st:delta(d * s.smod())
                            s.len:delta(d * s.lmod())
                        end,
                        st = _enc.txt.number:new {
                            x = layout[2].x[2][1],
                            y = layout[2].y[1],
                            n = 2,
                            action = function(s, v)
                                ndls.tp[i].start(v)

                                sc.loop_start(i, v * sc.region_length(i)) -- v is 0-1
                                s.p.len()
                            end
                            enabled = noalt
                        },
                        len = _enc.txt.number:new {
                            label = 'end',
                            x = layout[2].x[3][1],
                            y = layout[2].y[1],
                            n = 3,
                            action = function(s, v) 
                               ndls.tp[i].length(v)
                               
                              local len = util.clamp(v * sc.region_length(i), 0.001, 1 - s.p.start())
                              sc.loop_length(i, len)
                    
                              return len / sc.region_length(i)
                            end
                            enabled = noalt
                        },
                        smod = _enc.txt.number:new {
                            label = 'mod',
                            x = layout[2].x[2][1],
                            y = layout[2].y[1],
                            n = 2,
                            enabled = alt
                        },
                        lmod = _enc.txt.number:new {
                            label = 'mod',
                            x = layout[2].x[3][1],
                            y = layout[2].y[1],
                            n = 3,
                            enabled = alt
                        }
                    },
                    p = {
                        modulate = function(s, d) 
                            s.bnd:delta(d * s.fm())
                        end,
                        bnd = _enc.txt.number:new {
                            x = layout[2].x[2][1],
                            y = layout[2].y[1],
                            range = { -1, 1 }
                            n = 2,
                            action = function(s, v) 
                                sc.rate2(i, math.pow(2, v))
                            end,
                            enabled = noalt
                        },
                        fm = _enc.txt.number:new {
                            x = layout[2].x[3][1],
                            y = layout[2].y[1],
                            n = 3,
                            enabled = noalt
                        },
                        fade = _enc.txt.number:new {
                            x = layout[2].x[2][1],
                            y = layout[2].y[1],
                            units = 's',
                            n = 2,
                            action = function(s, v) 
                                sc.fade_time(i, v)
                            end,
                            enabled = alt
                        }
                    },
                    f = {
                        modulate = function(s, d) 
                            s.frq:delta(d * s.fm())
                        end,
                        frq = _enc.txt.number:new {
                            x = layout[2].x[2][1],
                            y = layout[2].y[1],
                            n = 2,
                            v = 0.7,
                            action = function(s, v) 
                                sc.post_filter_fc(i, util.linexp(0, 1, 1, 12000, v))
                            end,
                            enabled = noalt
                        },
                        fm = _enc.txt.number:new {
                            x = layout[2].x[3][1],
                            y = layout[2].y[1],
                            n = 3,
                            enabled = noalt
                        },
                        res = _enc.txt.number:new {
                            x = layout[2].x[2][1],
                            y = layout[2].y[1],
                            n = 2,
                            action = function(s, v) 
                                softcut.post_filter_rq(i,1 - v)
                            end,
                            enabled = alt
                        },
                        shp = _enc.txt.number:new {
                            x = layout[2].x[3][1],
                            y = layout[2].y[1],
                            n = 3,
                            action = function() 
                                supercut.post_filter_dry(i, 0)
                                supercut.post_filter_lp(i, 1)
                            end,
                            enabled = alt
                        }
                    }
                }:each(function(k, s) s.enabled = function() return ndls.tp[i].screen.pager() == k end end)
            },
            level = _arc.fader:new {
                ring = function() return ndls.arcpg.vertical and i or 1 end,
                x = { 8, 54 },
                action = function(s) s.p.screen.pg.l.lvl(v) end,
                enabled = function() return ndls.arcpg()[i][1] == 1 end
            },
            position = _arc.cycle:new {
                ring = function() return ndls.arcpg.vertical and i or 2 end,
                handler = function(s, ring, d) -- weird use !
                    s.p.screen.pg.m.v(s.p.screen.pg.m.v() + d)
                end,
                enabled = function() return ndls.arcpg()[i][2] == 1 and noalt() end
            },
            mu = _arc.fader:new {
                ring = function() return ndls.arcpg.vertical and i or 2 end,
                x = { 0, 54 },
                action = function(s, v) s.p.screen.pg.m.mu(v) end,
                enabled = function() return ndls.arcpg()[i][2] == 1 and alt() end
            },
            start = _arc.value:new {
                ring = function() return ndls.arcpg.vertical and i or 3 end, -- all params can be functions !
                action = function(s, v) s.p.screen.pg.w.st(v) end,
                enabled = function() return ndls.arcpg()[i][3] == 1 end
            },
            length = _arc.value:new {
                ring = function() return ndls.arcpg.vertical and i or 4 end,
                x = { 1, 64 },
                action = function(s, v) return s.p.screen.pg.w.len(v) end,
                enabled = function() return ndls.arcpg()[i][4] == 1 end,
                output = { enabled = false } --
            },
            endpt = _arc.value:new {
                ring = function() return ndls.arcpg.vertical and i or 4 end,
                x = { 1, 64 },
                action = function(s) return s.p.start() + s.p.length() end, --
                enabled = function() return ndls.arcpg()[i][4] == 1 end,
                input = { enabled = false }
            },
            window  = _arc.range:new {
                ring = function() return ndls.arcpg.vertical and i or { 3, 4 } end, -- multiple rings
                lvl = 4,
                action = function(s)
                    return { s.p.start(), s.p.endpt() }
                end,
                order = -1,
                enabled = function() return ndls.arcpg()[i][3] == 1 or ndls.arcpg()[i][4] == 1 end,
            },
            buffer = _grid.value:new {
                x = { 8, 15 }, y = i + 3, v = i
                action = function(s, v)
                    sc.buffer_steal_region(i, v + 1)
                end
            },
            punchin = nil,
            resetwindow = function(s)
                s.p.start(sc.region_start(i))
                s.p.length(sc.region_length(i))
            end,
            rec = _grid.toggle:new {
                x = 1, y = i + 3,
                action = function(s, v)
                    if not s.p.play() and v == 1 then
                        sc.buffer_clear_region(i)
                        sc.buffer_steal_home_region(i, s.p.buffer())
                        s.p.resetwindow(s)
                        
                        s.p.punchin = util.time()
                    end

                    if v == 0 and s.p.punchin then
                        sc.region_length(i, punchin)
                        s.p.resetwindow(s)

                        s.p.punchin = nil
                    end
                    
                    sc.rec(i, v)
                end
            },
            play = _grid.toggle:new {
                x = 2, y = i + 3, lvl = { 4, 15 },
                action = function(s, v)
                    if v == 1 and s.p.punchin then
                        sc.region_length(i, punchin)
                        s.p.resetwindow(s)

                        s.p.punchin = nil
                    end

                    sc.play(i, v)
                end
            },
            slew_reset = metro.init(function() 
                sc.rate_slew(i, 0)
            end, 0, 1),
            rev = _grid.toggle:new {
                x = 1, y = i, lvl = { 4, 15 },
                action = function(s, v, t)
                    local st = (1 + (math.random() * 0.5)) * t
                    sc.rate_slew(i, st)
                    s.p.slew_reset:start(st)

                    sc.rate3(i, (v == 1) and 1 or -1)
                end
            },
            rate = _grid.glide:new {
                x = { 2, 11 }, y = i, v = 7
                action = function(s, v, t) 
                    local st = (1 + (math.random() * 0.5)) * t
                    sc.rate_slew(i, st)
                    s.p.slew_reset:start(st)

                    sc.rate(i, math.pow(2, v - 7))
                end,
                indicator = _grid.value.output:new { ---
                    x = 9, y = i, lvl = 4, order = -1
                }
            },
            pre_level = _control:new { -- control w/o input or output ! only bangs + sets/gets !
                v = 0, mul = 1, action = function(s, v) sc.pre_level(i, v * s.mul) end
            },
            feedback = _control:new { 
                v = 0, mul = 0, action = function(s, v) sc.level_cut_cut(i, i, v * s.mul) end
            },
            route = _grid.toggle:new {
                x = { 4, 7 }, y = 3 + i,
                action = function(s, v) -- change v to matrix ?
                    for j,w in ipairs(v) do 
                        if j == i and w == 1 then
                            s.p.pre_level.mul = 0
                            s.p.pre_level() ------ or s.p.pre_level() ?

                            s.p.feedback.mul = 1
                            s.p.feedback()
                        else 
                            sc.level_cut_cut(i, j, w) 

                            s.p.pre_level.mul = 1
                            s.p.pre_level() ------

                            s.p.feedback.mul = 0
                            s.p.feedback()
                        end
                    end
                end,
                indicator = _grid.value.output:new { ---
                    x = i + 3, y = i + 3, lvl = 4, order = -1
                }
            }
        }
    end),
    screen_global = true,
    screen = {
        enabled = function() return ndls.screen_global end,
        fb = _enc.txt.number:new { -- if not self.label then self.label = self.k end
            x = layout[2].x[1][1],
            y = layout[2].y[1],
            n = 1
        },
        dw = _enc.txt.number:new {
            label = 'd/w',
            x = layout[2].x[2][1],
            y = layout[2].y[1],
            n = 2,
            enabled = noalt
        },
        sr = _enc.txt.number:new {
            x = layout[2].x[3][1],
            y = layout[2].y[1],
            n = 3,
            enabled = noalt
        },
        drv = _enc.txt.number:new {
            x = layout[2].x[2][1],
            y = layout[2].y[1],
            n = 2,
            enabled = alt
        },
        wdth = _enc.txt.number:new {
            x = layout[2].x[3][1],
            y = layout[2].y[1],
            n = 3,
            enabled = alt
        }
    },
    alt = _key.momentary:new {
        n = 2
    },
    pat = _grid.pattern:new {
        x = 16,
        y = { 1, 8 },
        lvl = { 4, 15 },
        target = function(s) return s.p.tp end
    },
    arcpg = _grid.control:new {
        x = { 12, 15 }, y = { 1, 4 }, held = {}, vertical = true, lvl = 15,
        v = {
            { 1, 0, 0, 0 },
            { 1, 0, 0, 0 },
            { 1, 0, 0, 0 },
            { 1, 0, 0, 0 }
        },
        handler = function(s, x, y, z) 
            if z == 1 then
                table.insert(s.held, { x = x - s.x[1], y = y - s.y[1] })
            else
                if #s.held > 1 then
                    if s.held[1].x == s.held[2].x then s.vertical = true
                    elseif s.held[1].y == s.held[2].y then s.vertical = false end
                else
                    for i = 0,3 do --y
                        for j = 0,3 do --x 
                            -- bugs looove lines like this !
                            s.v[i + 1][j + 1] = (s.vertical and x == j) and 1 or ((not s.vertical and y == i) and 1 or 0)
                        end 
                    end
                end
 
                for i,v in ipairs(s.held) do
                    if v.x == x - s.x[1] and v.y == y - s.y[1] then table.remove(s.held, i) end
                end
            end
        end,
        redraw = function(s) 
            for i = 0,3 do for j = 0,3 do s.g:led(s.x[1] + j, s.y[1] + i, s.v[i + 1][j + 1] * s.lvl) end end
        end,
        action = function(s) s.device.a.dirty = true end -- is there a cleaner way to do this ? it's kinda niche
    }
} :connect { 
    g = grid.connect(1), 
    arc = arc.connect(1),
    screen = screen, 
    enc = enc, 
    key = key
}
