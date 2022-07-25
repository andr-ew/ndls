alt = false
view = { track = 1, page = 1 }

voices = tall and 6 or 4
buffers = voices
slices = 9

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

--this seems to be affecting slice across voices. there needs to be a dedicated play region per voice, per buffer
function update_reg(voice, buf, slice)
    local i = voice
    local b = sc.buffer[voice]
    local s = sc.slice:get(voice)

    if b == buf and s == slice then
        local pfx = i..' buffer '..b..' slice '..s
        local st = params:get('start '..pfx)
        local en = params:get('end '..pfx)

        reg.play[b][i]:expand()
        reg.play[b][i]:set_start(st, 'fraction')
        reg.play[b][i]:set_end(en, 'fraction')

        nest.screen.make_dirty(); nest.arc.make_dirty()
    end
end

local set_start_scoped = {}
local set_end_scoped = {}
for n = 1, voices do
    set_start_scoped[n] = {}
    set_end_scoped[n] = {}

    for b = 1, buffers do
        set_start_scoped[n][b] = {}
        set_end_scoped[n][b] = {}

        for sl = 1, slices do
            local pfx = n..' buffer '..b..' slice '..sl

            set_start_scoped[n][b][sl] = multipattern.wrap_set(
                mpat, 'start '..pfx, function(v) params:set('start '..pfx, v) end
            )
            set_end_scoped[n][b][sl] = multipattern.wrap_set(
                mpat, 'end '..pfx, function(v) params:set('end '..pfx, v) end
            )
        end
    end
end
get_set_start = function(voice)
    local b = sc.buffer[voice]
    local sl = sc.slice:get(voice)
    return set_start_scoped[voice][b][sl]
end
get_set_end = function(voice)
    local b = sc.buffer[voice]
    local sl = sc.slice:get(voice)
    return set_end_scoped[voice][b][sl]
end
get_start = function(voice, units, abs)
    units = units or 'fraction'
    return reg.play:get_start(voice, units, abs)
end
get_end = function(voice, units, abs)
    units = units or 'fraction'
    return reg.play:get_end(voice, units, abs)
end
get_len = function(voice, units)
    units = units or 'fraction'
    return reg.play:get_length(voice, units)
end

