alt = false
view = { track = 1, page = 1 }

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
    --TODO: reset all mparam tracks of buffer on buffer clear, 
    --      reset all wpram tracks of buffer on buffer punch-out
    reset = function(s, n)
        local b = sc.buffer[n]
        s:set(n, b, 1)
        
        mparams:reset(n, b)
        wparams:reset(n, b)
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
