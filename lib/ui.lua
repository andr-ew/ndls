function pattern_time:resume()
    if self.count > 0 then
        self.prev_time = util.time()
        self.process(self.event[self.step])
        self.play = 1
        self.metro.time = self.time[self.step] * self.time_factor
        self.metro:start()
    end
end

local pattern, mpat = {}, {}
for i = 1,8 do
    pattern[i] = pattern_time.new() 
    mpat[i] = multipattern.new(pattern[i])
end

local view = {
    { 1, 0, 0, 0 },
    { 1, 0, 0, 0 },
    { 1, 0, 0, 0 },
    { 1, 0, 0, 0 },
}
local vertical = true
local alt = false

local App = {}

function App.grid(size)
    local varibright = true
    local shaded = varibright and { 4, 15 } or { 0, 15 }
    local mid = varibright and 4 or 15
    local mid2 = varibright and 8 or 15

    local function Voice(n)
        local top, bottom = n, n + ndls.voices

        _phase = Components.grid.phase()
        
        local _params = {}
        _params.rec = to.pattern(mpat, 'rec '..n, Grid.toggle, function()
            return {
                x = 1, y = bottom, 
                state = of.param('rec '..n),
            }
        end)
        _params.play = to.pattern(mpat, 'play '..n, Grid.toggle, function()
            return {
                x = 2, y = bottom, lvl = shaded,
                state = {
                    sc.punch_in[ndls.zone[n]].recorded and params:get('play '..n) or 0,
                    function(v)
                        local recorded = sc.punch_in[ndls.zone[n]].recorded
                        local recording = sc.punch_in[ndls.zone[n]].recording

                        if recorded or recording then 
                            params:set('play '..n, v)
                        end
                    end
                },
            }
        end)
        _params.zoom = to.pattern(mpat, 'zoom '..n, Grid.toggle, function() 
            return {
                x = 3, y = bottom, edge = 'falling',
                state = { sc.get_zoom(n) and 1 or 0 },
                action = function(v, t) sc.zoom(n, v > 0, t) end
            }
        end)
        _params.zone = to.pattern(mpat, 'zone '..n, Grid.number, function()
            return {
                x = { 4, 13 }, y = bottom,
                state = {
                    ndls.zone[n],
                    function(v) ndls.zone:set(v, n) end
                }
            }
        end)
        _params.send = to.pattern(mpat, 'send '..n, Grid.toggle, function()
            return {
                x = 14, y = bottom, lvl = shaded,
                state = of.param('send '..n),
            }
        end)
        _params.ret = to.pattern(mpat, 'return '..n, Grid.toggle, function()
            return {
                x = 15, y = bottom,
                state = of.param('return '..n),
            }
        end)
        _params.rev = to.pattern(mpat, 'rev '..n, Grid.toggle, function()
            return {
                x = 5, y = top, edge = 'falling', lvl = shaded,
                state = { params:get('rev '..n) },
                action = function(v, t)
                    sc.slew(n, (t < 0.2) and 0.025 or t)
                    params:set('rev '..n, v)
                end,
            }
        end)
        _params.rate = to.pattern(mpat, 'rate '..n, Grid.number, function()
            return {
                x = { 6, 15 }, y = top, filtersame = true,
                state = { params:get('rate '..n) + 8 },
                action = function(v, t)
                    sc.slew(n, t)
                    params:set('rate '..n, v - 8)
                end,
            }
        end)

        return function()
            if sc.lvlmx[n].play == 1 and sc.punch_in[ndls.zone[n]].recorded then
                _phase{ 
                    x = { 1, 16 }, y = top,
                    phase = sc.phase[n].rel,
                }
            end

            for _, _param in pairs(_params) do _param() end
        end
    end

    local _view = Components.grid.view()
    
    _voices = {}
    for i = 1, ndls.voices do
        _voices[i] = Voice(i)
    end

    local _patrec = PatternRecorder()

    return function()
        _view{
            x = 1, y = 1, lvl = 15,
            view = view,
            vertical = { vertical, function(v) vertical = v end },
            action = nest.arc.make_dirty
        }
        
        for i, _voice in ipairs(_voices) do
            _voice{}
        end
        
        _patrec{
            x = 16, y = { 1, 8 }, pattern = pattern,
        }
    end
end

function App.arc(map)
    local Destinations = {}

    function Destinations.vol(n, x)
        local _num = to.pattern(mpat, 'vol '..n, Arc.number, function() 
            return {
                n = tonumber(vertical and n or x),
                sens = 0.25, max = 2.5, cycle = 1.5,
                state = of.param('vol '..n),
            }
        end)

        return function() _num() end
    end

    function Destinations.cut(n, x)
        local _cut = to.pattern(mpat, 'cut '..n, Arc.control, function() 
            return {
                n = tonumber(vertical and n or x),
                x = { 42, 24+64 }, sens = 0.25, 
                redraw_enabled = false,
                controlspec = of.controlspec('cut '..n),
                state = of.param('cut '..n),
            }
        end)

        local _filt = Components.arc.filter()

        local _type = to.pattern(mpat, 'type '..n, Arc.option, function() 
            return {
                n = tonumber(vertical and n or x),
                options = 4, sens = 1/64,
                x = { 27, 41 }, lvl = 12,
                --[[
                state = {
                    params:get('type '..n),
                    function(v) params:set('type '..n, v//1) end
                },
                --]]
                action = function(v) params:set('type '..n, v//1) end
            }
        end)

        return function() 
            _filt{
                n = tonumber(vertical and n or x),
                x = { 42, 24+64 },
                type = params:get('type '..n),
                cut = params:get('cut '..n),
            }

            if alt then 
                _type()
            else
                _cut() 
            end
        end
    end

    function Destinations.st(n, x)
        _st = Components.arc.st(mpat)

        return function() 
            if sc.punch_in[ndls.zone[n]].recorded then
                _st{
                    n = tonumber(vertical and n or x),
                    x = { 33, 64+32 }, lvl = { 4, 15 },
                    reg = sc.get_zoom(n) and reg.zoom or reg.play, 
                    nreg = n,
                    phase = sc.phase[n].rel,
                    show_phase = sc.lvlmx[n].play == 1,
                    nudge = alt,
                    sens = 1/1000,
                }
            end
        end
    end

    function Destinations.len(n, x)
        _len = Components.arc.len(mpat)

        return function() 
            if sc.punch_in[ndls.zone[n]].recorded then
                _len{
                    n = tonumber(vertical and n or x),
                    x = { 33, 64+32 }, 
                    reg = sc.get_zoom(n) and reg.zoom or reg.play, 
                    nreg = n,
                    phase = sc.phase[n].rel,
                    show_phase = sc.lvlmx[n].play == 1,
                    nudge = alt,
                    sens = 1/1000,
                    lvl_st = alt and 15 or 4,
                    lvl_en = alt and 4 or 15,
                    lvl_ph = 4,
                }
            end
        end
    end

    local _params = {}
    for y = 1,4 do --track
        _params[y] = {}

        for x = 1,4 do --map item

            _params[y][x] = Destinations[map[x]](y, x)
        end
    end

    return function()
        for y = 1,4 do for x = 1,4 do
            if view[y][x] > 0 then
                _params[y][x]()
            end
        end end
    end
end

function App.norns()
    _alt = Key.momentary()

    return function()
        _alt{
            n = 1, 
            state = {
                alt and 1 or 0,
                function(v)
                    alt = v==1
                    nest.arc.make_dirty()
                end
            }
        }
    end
end

local _app = {
    grid = App.grid(),
    arc = App.arc({ 'vol', 'cut', 'st', 'len' }),
    norns = App.norns(),
}

nest.connect_grid(_app.grid, grid.connect(), 60)
nest.connect_arc(_app.arc, arc.connect(), 90)
nest.connect_enc(_app.norns)
nest.connect_key(_app.norns)
--nest.connect_screen(_app.norns)
