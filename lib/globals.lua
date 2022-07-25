function pattern_time:resume()
    if self.count > 0 then
        self.prev_time = util.time()
        self.process(self.event[self.step])
        self.play = 1
        self.metro.time = self.time[self.step] * self.time_factor
        self.metro:start()
    end
end

pattern, mpat = {}, {}
for i = 1,16 do
    pattern[i] = pattern_time.new() 
    mpat[i] = multipattern.new(pattern[i])
end

alt = false
view = { track = 1, page = 1 }

voices = tall and 6 or 4
buffers = voices
slices = 9

local set_start_scoped = {}
local set_end_scoped = {}
for b = 1, buffers do
    set_start_scoped[b] = {}
    set_end_scoped[b] = {}

    for sl = 1, slices do
        set_start_scoped[b][sl] = multipattern.wrap_set(mpat, 'start '..b..' '..sl, function(v) 
            reg.play[b][sl]:set_start(v, 'fraction')
            nest.screen.make_dirty(); nest.arc.make_dirty()
        end)
        set_end_scoped[b][sl] = multipattern.wrap_set(mpat, 'end '..b..' '..sl, function(v) 
            reg.play[b][sl]:set_end(v, 'fraction')
            nest.screen.make_dirty(); nest.arc.make_dirty()
        end)
    end
end
get_set_start = function(voice)
    local b = sc.buffer[voice]
    local sl = sc.slice:get(voice)
    return set_start_scoped[b][sl]
end
get_set_end = function(voice)
    local b = sc.buffer[voice]
    local sl = sc.slice:get(voice)
    return set_end_scoped[b][sl]
end
get_start = function(voice, units)
    units = units or 'fraction'
    return reg.play:get_start(voice, units)
end
get_end = function(voice, units)
    units = units or 'fraction'
    return reg.play:get_end(voice, units)
end
get_len = function(voice, units)
    units = units or 'fraction'
    return reg.play:get_length(voice, units)
end

