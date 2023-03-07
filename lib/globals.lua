alt = false
view = { track = 1, page = 1 }
page_names = { 'm', 't', 'f' }

voices = tall and 6 or 4
buffers = voices
slices = 9

tracks = voices
presets = slices

arc_vertical = false
arc_view = tall and {
    { 1, 1, 1, 1 },
    { 0, 0, 0, 0 },
    { 0, 0, 0, 0 },
    { 0, 0, 0, 0 },
    { 0, 0, 0, 0 },
    { 0, 0, 0, 0 },
} or {
    { 1, 1, 1, 1 },
    { 0, 0, 0, 0 },
    { 0, 0, 0, 0 },
    { 0, 0, 0, 0 },
}


-- function pattern_time:resume()
--     if self.count > 0 then
--         self.prev_time = util.time()
--         self.process(self.event[self.step])
--         self.play = 1
--         self.metro.time = self.time[self.step] * self.time_factor
--         self.metro:start()
--     end
-- end

pattern, mpat = {}, {}
for i = 1,16 do
    pattern[i] = pattern_time.new() 
    mpat[i] = multipattern.new(pattern[i])
end

wparams = windowparams:new()
mparams = metaparams:new()

view_options = {}

function of_mparam(track, id)
    return { 
        mparams:get(track, id),
        mparams:get_setter(track, id)
    }
end

preset = { --[voice][buffer] = preset
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
            mparams:reset_presets(i, b)
            wparams:reset_presets(i, b)
        end

        s:set(n, b, 1)
    end,
    get = function(s, n)
        local b = sc.buffer[n]
        return s[n][b]
    end
}

do
    function pattern_write(slot)
        local name = 'pset-'..string.format("%02d", slot)
        local data = {
            pattern = {},
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

        local fname = norns.state.data..name..'.data'
        tab.save(data, fname)
    end
    function pattern_read(slot)
        local name = 'pset-'..string.format("%02d", slot)
        local fname = norns.state.data..name..'.data'
        local data = tab.load(fname)

        if data then
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

local function action_read(file, name, slot)
    print('pset read', file, name, slot)
    sc.read(slot)

    params:bang()

    pattern_read(slot)
end
local function action_write(file, name, slot)
    sc.write(slot)

    pattern_write(slot)
end
local function action_delete(file, name, slot)
    --TODO: delete files
end

params.action_read = action_read
params.action_write = action_write
params.action_delete = action_delete

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
-- clock.run(function() 
--     while true do
--         freeze_patrol:patrol() 
--         clock.sleep(1/fps.patrol)
--     end
-- end)
