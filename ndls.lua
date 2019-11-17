include "nest_000000"

local g_ = grid_:new()
local s_ = screen_:new()
local sc_ = softcut_:new(1, 2, 3, 4)

g_.channels = {}
s_.channels = {}

for i = 1, 4 do
    g_.channels[i] = {
        looper = softlooper_:new(sc_, i),
        stutter = grid_momentary:new{
            x = 0,
            y = i,
            output.enabled = false,
            link = g_.channels[i].looper.stutter
        },
        speed = grid_glide:new{
            x = {1, 14},
            y = i,
            v = 7,
            link = g_.channels[i].looper.rateglide
        },
        phase = grid_value:new{
            x = {0, 15},
            y = i,
            input.enabled = false,
            output.z = -1,
            link = sc_[i].phase
        },
        reverse = grid_toggle:new{
            x = 15,
            y = i,
            output.enabled = false,
            link = g_.channels[i].looper.reverse
        },
        record = grid_toggle:new{
            x = 0,
            y = i + 4,
            off = 4,
            link = g_.channels[i].looper.partyrecord
        },
        play = grid_toggle:new{
            x = 1,
            y = i + 4,
            link = g_.channels[i].looper.partyplay
        },
        buffer = value:new{
            x = {2, 5},
            y = i + 4,
            v = i,
            link = g_.channels[i].looper.segment
        },
        sync = grid_toggle:new{
            x = 6,
            y = i + 4,
            off = 4,
            link = g_.channels[i].looper.sync
        },
        route = grid_toggle:new{
            x = {7, 10},
            y = i + 4,
            event = function(v) {
                for i = 1, 4 do
                    sc_[i].levelcutcut = { i, v }
                end
            }
        },
        glideon = grid_toggle:new{
            x = 11,
            y = i + 4,
            off = 4,
            event = function() {
                
            }
        },
        toggle1 = grid_toggle:new{
            x = 12,
            y = i + 4
        },
        toggle2 = grid_toggle:new{
            x = 13,
            y = i + 4
        },
        pattern = grid_pattern:new{
            x = 14,
            y = i + 4,
            target = g_
        }
    }
    
    s_.channels[i] = {
        level = screen_value:new{
            enabled = function() return s_.pager.set(i) end,
            yalign = CENTER,
            x = 1,
            y = 1,
            input = _enc_value:new{
                n = 2,
                range = { 0, 1.2 }
            },
            label = "level"
        },
        rate = screen_value:new{
            enabled = function() return s_.pager.set(i) end,
            yalign = CENTER,
            x = 2,
            y = 1,
            input = _enc_value:new{
                n = 3,
                range = { 0.5, 2 }
            },
            label = "rate",
            link = g_.channels[i].looper.rate2
        }
    }
end

g_.pager = value:new{
    x = 15,
    y = {4, 7},
    bg = 4,
    link = s_.pager
}

s_._.sections = {
    x = { MAX, MAX },
    y = { MAX, MAX, MIN }
}

s_.pager = screen_tabs:new{
    x = {1, 2},
    y = 3,
    count = 4,
    v = 0
}

s_.prev = screen_momentary:new{
    x = 1,
    y = 2,
    yalign = CENTER,
    input = _key_momentary:new{
        n = 2
    },
    label = "prev",
    event = function()
        g_.pager.set(wrap(g_.pager.get() - 1, 0, 4))
    end
}

s_.nxt = screen_momentary:new{
    x = 2,
    y = 2,
    yalign = CENTER,
    input = _key_momentary:new{
        n = 3
    },
    label = "next",
    event = function()
        g_.pager.set(wrap(g_.pager.get() + 1, 0, 4))
    end
}