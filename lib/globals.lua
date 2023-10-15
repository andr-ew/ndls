alt = false
view = { track = 1, page = 1, modal = 'none', modal_index = 1, }
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

local function process_param(arg) 
    local id, v, retrigger = table.unpack(arg)
    if retrigger then
        local silent = true
        params:set(id, v, silent) 
        params:lookup_param(id):bang()
    else
        params:set(id, v) 
    end
end

pattern = {}
for i = 1,16 do
    pattern[i] = pattern_time.new() 
    pattern[i].process = process_param 
end

set_param = function(id, v, retrigger)
    local t = { id, v, retrigger }
    process_param(t)
    for i,pat in ipairs(pattern) do pat:watch(t) end
end

wparams = windowparams:new()
mparams = metaparams:new()

set_wparam = function(track, id, v)
    local p_id = wparams:get_id(track, id)
    set_param(p_id, v)
end
set_mparam = function(track, id, v) 
    local p_id = mparams:get_id(track, id)
    set_param(p_id, v)
end

function of_wparam(track, id, units, abs)
    return { 
        wparams:get(track, id, units, abs),
        set_wparam, track, id,
    }
end
function of_mparam(track, id)
    return { 
        mparams:get(track, id),
        set_mparam, track, id,
    }
end

view_options = {}

preset = { --[voice][buffer] = preset
    --TODO: depricate
    set = function(s, n, b, v, silent)
        local id = 'preset '..n..' buffer '..b
        params:set(id, v, true) 
        if not silent then params:lookup_param(id):bang() end
    end,
    update = function(s, n, b)
        if b == sc.buffer[n] then
            mparams:bang(n)
            wparams:bang(n)
            sc.trigger(n)
        end
    end,
    reset = function(s, n, silent)
        local b = sc.buffer[n]

        for i = 1, voices do
            mparams:reset_presets(i, b)
            wparams:reset_presets(i, b)
        end

        s:set(n, b, 1, silent)
    end,
    bang = function(s, n, b)
        local id = 'preset '..n..' buffer '..b
        params:lookup_param(id):bang()
    end,
    get = function(s, n)
        local b = sc.buffer[n]
        return s[n][b]
    end
}

pset_default_slot = 1
pset_last_session_slot = 2

do
    function pattern_write(slot)
        local name = 'pset-'..string.format("%02d", slot)
        local data = {
            pattern = {},
        }
        for i,pat in ipairs(pattern) do
            local d = {}
            d.data = pat.data
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
    print('pset action read', file, name, slot)

    sc.read(slot)

    params:bang()

    pattern_read(slot)
end
local function action_write(file, name, slot)
    print('pset action write', file, name, slot)

    sc.write(slot)

    pattern_write(slot)
end
local function action_delete(file, name, slot)
    print('pset action delete', file, name, slot)

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

fileselect_dir = _path.audio

function fileselect_callback(path)
    sc.loadsample(view.modal_index, path)
    screen_clock = crops.connect_screen(_app.norns, fps.screen)
    for i = 1,tracks do
        if params:get('buffer '..i) == view.modal_index then
            preset:reset(i)
            params:set('play '..i, 1)
            break
        end
    end
end
