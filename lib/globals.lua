alt = false
view = { track = 1, page = 1 }
page_names = { 'MIX', 'WINDOW', 'FILTER', 'LFO' }
MIX, WINDOW, FILTER, LFO = 1, 2, 3, 4

voices = tall and 6 or 4
buffers = voices
slices = 9

tracks = voices
presets = slices

function pattern_time:resume()
    if self.count > 0 then
        self.prev_time = util.time()
        self.process(self.event[self.step])
        self.play = 1
        self.metro.time = self.time[self.step] * self.time_factor
        self.metro:start()
    end
end

pattern, mpat, pattern_states = {}, {}, { main = {}, alt = {} }
for i = 1,16 do
    pattern[i] = pattern_time.new() 
    mpat[i] = multipattern.new(pattern[i])
end
for i = 1,8 do
    pattern_states.main[i] = 0
    pattern_states.alt[i] = 0
end

wparams = windowparams:new()
mparams = metaparams:new()

view_options = {}

function mparams_scope(track, id, set_sum)
    local base
    if not sc.punch_in:is_recorded(track) then
        base = true
    elseif params:get(id..'_view') == view_options.vals.preset then
        base = alt
    elseif params:get(id..'_view') == view_options.vals.base then
        base = not alt
    end

    if base then
        return 'base'
    else
        return (nest.is_drawing() or set_sum) and 'sum' or 'preset'
    end
end
function of_mparam(track, id)
    return { 
        mparams:get(track, id, mparams_scope(track, id)),
        mparams:get_setter(track, id, mparams_scope(track, id))
    }
end

preset = { --[voice][buffer] = slice
    --TODO: depricate
    set = function(s, n, b, v)
        local id = 'preset '..n..' buffer '..b
        params:set(id, v, true) 
        params:lookup_param(id):bang()
    end,
    update = function(s, n, b)
        if b == sc.buffer[n] then
            mparams:bang(n)
            wparams:bang(n)
            sc.trigger(n)
        end
    end,
    reset = function(s, n)
        local b = sc.buffer[n]

        for i = 1, voices do
            mparams:reset(i, b, 'preset')
            wparams:reset(i, b, 'preset')
        end

        s:set(n, b, 1)
    end,
    get = function(s, n)
        local b = sc.buffer[n]
        return s[n][b]
    end
}

--TODO: read & write based on pset #, call on params.action_read/action_write
do
    function pattern_write()
        local data = {
            pattern = {},
            pattern_states = pattern_states,
        }
        for i,pat in ipairs(pattern) do
            local d = {}
            d.count = pat.count
            d.event = pat.event
            d.time = pat.time
            d.time_factor = pat.time_factor
            d.step = pat.step
            d.play = pat.play
            
            data.pattern[i] = d
        end

        tab.save(data, norns.state.data..'patterns.data')
    end
    function pattern_read()
        local data = tab.load(norns.state.data..'patterns.data')
        if data then
            pattern_states = data.pattern_states

            for i,pat in ipairs(data.pattern) do
                for k,v in pairs(pat) do
                    pattern[i][k] = v
                end

                if pattern[i].play > 0 then
                    pattern[i]:start()
                end
            end
        end
    end
end

fps = { grid = 30, arc = 90, screen = 30, patrol = 30 }

local freeze_thresh = 1
freeze_patrol = {
    t = { 
        grid = util.time(),  
        screen = util.time(),
        arc = util.time()
    },
    delta = { grid = 0, screen = 0, arc = 0 },
    ping = function(s, k)
        local now = util.time()
        --s.tlast[k] = s.t[k]
        s.t[k] = now
    end,
    patrol = function(s) 
        local now = util.time()
        for _,k in ipairs{ 'grid', 'screen', 'arc' } do
            if now - s.t[k] > freeze_thresh then
                if not (k=='screen' and _menu.mode) then --checking _menu.mode probs dangerous 👺
                    print(k..' is frozen !!! 🥶')
                end
            end
        end
    end
}
clock.run(function() 
    while true do
        freeze_patrol:patrol() 
        clock.sleep(1/fps.patrol)
    end
end)
