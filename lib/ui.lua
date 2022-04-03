local pattern, mpat = {}, {}
for i = 1,ndls.voices do
    pattern[i] = pattern_time.new() 
    mpat[i] = multipattern.new(pattern[i])
end

local view = {
    { 1, 0, 0, 0 },
    { 1, 0, 0, 0 },
    { 1, 0, 0, 0 },
    { 1, 0, 0, 0 },
}
local vertical
local alt = false

local App = {}

function App.grid(size)
    local shaded = varibright and { 4, 15 } or { 0, 15 }
    local mid = varibright and 4 or 15
    local mid2 = varibright and 8 or 15

    --local _patrec = PatternRecorder()

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
            local recorded = sc.punch_in[ndls.zone[n]].recorded
            local recording = sc.punch_in[ndls.zone[n]].recording

            return {
                x = 2, y = bottom, lvl = shaded,
                state = {
                    recorded and params:get('play '..n) or 0,
                    function(v)
                        if recorded or recording then 
                            params:set('play '..n, v)
                        end
                    end
                },
            }
        end)
        --_zoom = Grid.toggle
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
                x = { 6, 15 }, y = top,
                state = { params:get('rate '..n) + 8 },
                action = function(v, t)
                    sc.slew(n, t)
                    params:set('rate '..n, v - 8)
                end,
            }
        end)

        return function()
            _phase{ 
                x = { 1, 16 }, y = top,
                phase = sc.phase[n].rel,
            }

            for _, _param in pairs(_params) do _param() end
        end
    end

    _voices = {}
    for i = 1, ndls.voices do
        _voices[i] = Voice(i)
    end

    _view = Components.grid.view()

    return function()
        for i, _voice in ipairs(_voices) do
            _voice{}
        end

        _view{
            x = 1, y = 1, lvl = 15,
            view = view,
            vertical = { vertical, function(v) vertical = v end }
        }
    end
end

function App.arc(map)
    local Destinations = {}

    function Destinations.vol(n, x)
        local _num = to.pattern(mpat, 'vol '..n, Grid.number, function() 
            return {
                n = tonumber(vertical and n or x),
                sens = 0.25, max = 2.5, cycle = 1.5,
                state = of.param('vol '..n),
            }
        end)

        return function() _num() end
    end

    function Destinations.cut(n, x)
        local _cut = to.pattern(mpat, 'cut '..n, Grid.control, function() 
            return {
                n = tonumber(vertical and n or x),
                x = { 42, 24+64 }, sens = 0.25, 
                redraw_enabled = false,
                controlspec = of.controlspec('cut '..n),
                state = of.param('cut '..n),
            }
        end)

        local _filt = Components.arc.filter()

        local _type = to.pattern(mpat, 'type '..n, Grid.control, function() 
            return {
                n = tonumber(vertical and n or x),
                options = 4, sens = 1/32,
                x = { 27, 41 }, lvl = 12,
                state = {
                    params:get('type '..n),
                    function(v) params:set('type '..n, v//1) end
                }
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
            _st{
                n = tonumber(vertical and n or x),
                x = { 33, 64+32 }, lvl = { 4, 15 },
                reg = reg.play, nreg = n,
                phase = sc.phase[y].rel,
                show = sc.lvlmx[y].play == 1 and sc.punch_in[ndls.zone[y]].recorded,
                nudge = alt,
                sens = 1/1000,
            }
        end
    end

    function Destinations.len(n, x)
        _len = Components.arc.len(mpat)

        return function() 
            _len{
                n = tonumber(vertical and n or x),
                x = { 33, 64+32 }, 
                reg = reg.play, nreg = n,
                phase = sc.phase[y].rel,
                show = sc.lvlmx[y].play == 1 and sc.punch_in[ndls.zone[y]].recorded,
                nudge = alt,
                sens = 1/1000,
                lvl_st = alt and 15 or 4,
                lvl_en = alt and 4 or 15,
                lvl_ph = 4,
            }
        end
    end

    _params = {}
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
        end
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
nest.connect_arc(_app.arc, arc.connect(), 60)
nest.connect_enc(_app.norns)
nest.connect_key(_app.norns)
nest.connect_screen(_app.norns)
