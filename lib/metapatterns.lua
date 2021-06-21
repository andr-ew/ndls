local pattern = require 'pattern_time'

function pattern:resume()
    if self.count > 0 then
        self.prev_time = util.time()
        self.process(self.event[self.step])
        self.play = 1
        self.metro.time = self.time[self.step] * self.time_factor
        self.metro:start()
    end
end
function pattern:save()
    return {
        count = self.count,
        step = self.step,
        time_factor = self.time_factor,
        time = self.time,
        event = self.event,
        play = self.play
    }
end
function pattern:load(src)
    self.count = src.count
    self.step = src.step
    self.time_factor = src.time_factor
    self.time = src.time
    self.event = src.event

    if src.play > 0 then self:resume() end
end

local metapattern = {}

function metapattern:new()
    local o = setmetatable({}, { __index = self })
    self:alloc()
end

function metapattern:set_scope(new, voice)
    if new == 'global' and self.scope == 'zone' then
        for i,v in ipairs(self) do self:free(i) end
        self.voice = nil
        self.scope = 'global'
    elseif new == 'zone' and not self.scope then
        self:free('global')
        self.voice = voice
        self.scope = 'zone'
    elseif self.scope == 'zone' then 
        if voice ~= self.voice then --flip current pattern to global
            self.scope = 'global'

            local i = ndls.zone[self.voice]
            self.global = self[i]
            self[i] = nil
            
            for j,v in ipairs(self) do self:free(j) end
            self.voice = nil
        end
    end
end

function metapattern:pattern()
    return self[self.scope == 'zone' and ndls.zone[self.voice] or 'global']
end

function metapattern:alloc()
    if self.scope == 'zone' then 
        local i = ndls.zone[self.voice]
        if not self[i] then
            self[i] = pattern.new()
            self[i].state = 0
        end
    else
        if not self.global then 
            self.global = pattern.new() 
            self.global.state = 0
        end
    end
end

function metapattern:free(i)
    i = i or 1
    if self[i] then self[i]:clear() end
    self[i] = nil
end

function metapattern:watch(v, id, vc, scope)
    if self:pattern().rec > 0 or self:pattern().overdub > 0 then
        self:set_scope(scope, vc)
        self:alloc()
        self:pattern():watch { id = id, v = v }
    end
end

function metapattern:rec_start()
    self:alloc()
    self:pattern():rec_start()
end

function metapattern:rec_stop() self:pattern():rec_stop() end
function metapattern:set_overdub(v) self:pattern():set_overdub(v) end
function metapattern:set_time_factor(v) self:pattern():set_time_factor(v) end
function metapattern:stop() self:pattern():stop() end
function metapattern:resume() self:pattern():resume() end

function metapattern:clear()
    if self.zone == 'global' then self.zone = nil end
    self:pattern():clear()
end

function metapattern:save()
end

function metapattern:load(src)
end

local metapatterns = {}

function metapatterns:watch(v, id, vc, scope)
    for i,v in ipairs(self) do
        v:watch(v, id, vc, scope)
    end
end

for i = 1,8 do metapatterns[i] = metapattern:new() end

-- ++property metapattern
_grid.metapattern = _grid.toggle {
    lvl = {
        0, ------------------ 0 empty
        function(s, d) ------ 1 empty, recording, no playback
            while true do
                d(4)
                clock.sleep(0.25)
                d(0)
                clock.sleep(0.25)
            end
        end,
        4, ------------------ 2 filled, paused
        15, ----------------- 3 filled, playback
        function(s, d) ------ 4 filled, recording, playback
            while true do
                d(15)
                clock.sleep(0.2)
                d(0)
                clock.sleep(0.2)
            end
        end,
    },
    edge = 'falling',
    include = function(s) --limit range based on pattern clear state
        local p = self.metapattern:pattern()

        if p.count > 0 then
            return { 2, 3 }
        else
            return { 0, 1 }
        end
    end,
    value = function(s) return self.metapattern:pattern().state end
    action = function(s, value, time, delta, add, rem, list, last)
        local set, p, v, t, d

        mp = self.metapattern
        local p = self.metapattern:pattern()
        t = time
        d = delta
        v = value
        set = function(val) p.state = val end

        local function stop_all()
        end

        if p then
            if t > 0.5 then -- hold to clear
                if s.stop then s:stop() end
                mp:clear()
                return set(0)
            else
                if p.count > 0 then
                    if d < 0.3 then -- double-tap to overdub
                        mp:resume()
                        mp:set_overdub(1)
                        return set(4)
                    else
                        if p.rec == 1 then --play pattern / stop recording
                            mp:rec_stop()
                            mp:start()
                            return set(3)
                        elseif p.overdub == 1 then --stop overdub
                            mp:set_overdub(0)
                            return set(3)
                        else
                            --clock.sleep(0.3)

                            if v == 3 then --resume pattern
                                -- if count == 1 then stop all patterns
                                stop_all()

                                mp:resume()
                            elseif v == 2 then --pause pattern
                                mp:stop() 
                                if s.stop then s:stop() end
                            end
                        end
                    end
                else
                    if v == 1 then --start recording new pattern
                        -- if count == 1 then stop all patterns
                        stop_all()

                        mp:rec_start()
                    end
                end
            end
        end
    end
}

return metapatterns
