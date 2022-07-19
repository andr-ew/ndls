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

