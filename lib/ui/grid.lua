local function App(wide, offset)
    local varibright = true
    local shaded = varibright and { 4, 15 } or { 0, 15 }
    local mid = varibright and 4 or 15
    local mid2 = varibright and 8 or 15

    --TODO: only enable when arc is connected AND wide

    view = {
        { 1, 1, 1, 1 },
        { 0, 0, 0, 0 },
        { 0, 0, 0, 0 },
        { 0, 0, 0, 0 },
    } or { 0, 0, 0, 0 }

    local function Voice(n)
        local top, bottom = n, n + voices

        local _phase = Components.grid.phase()
        
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
                    sc.punch_in[sc.buffer[n]].recorded and params:get('play '..n) or 0,
                    function(v)
                        local recorded = sc.punch_in[sc.buffer[n]].recorded
                        local recording = sc.punch_in[sc.buffer[n]].recording

                        if recorded or recording then 
                            params:set('play '..n, v)
                        end
                    end
                },
            }
        end)
        _params.buffer = to.pattern(mpat, 'buffer '..n, Grid.number, function()
            return {
                x = { 3, 6 }, y = bottom,
                state = {
                    sc.buffer[n],
                    function(v)
                        sc.buffer:set(n, v)

                        nest.arc.make_dirty()
                        nest.screen.make_dirty()
                    end
                }
            }
        end)
        local function Slices(args)
            local n = args.voice

            local _slices = {}
            for b = 1, buffers do
                _slices[b] = to.pattern(mpat, 'slice '..n..' '..b, Grid.number, function()
                    return {
                        x = { 7, 13 }, y = bottom,
                        state = {
                            sc.slice[n][b],
                            function(v)
                                sc.slice:set(n, b, v)

                                nest.arc.make_dirty()
                                nest.screen.make_dirty()
                            end
                        }
                    }
                end)
            end
            local _fill = Grid.fill()

            return function()
                local b = sc.buffer[n]
                if sc.punch_in[b].recorded then
                    _fill{ x = 7, y = bottom, lvl = 4 }

                    _slices[b]()
                end
            end
        end
        _params.slices = Slices{ voice = n }
        if wide then
            _params.send = to.pattern(mpat, 'send '..n, Grid.toggle, function()
                return {
                    x = 14, y = bottom, lvl = shaded,
                    state = of.param('send '..n),
                }
            end)
            _params.ret = to.pattern(mpat, 'return '..n, Grid.toggle, function()
                return {
                    x = 15, y = bottom, lvl = shaded,
                    state = of.param('return '..n),
                }
            end)
        end
        _params.rev = to.pattern(mpat, 'rev '..n, Grid.toggle, function()
            return {
                x = wide and 7 or 2, y = top, edge = 'falling', lvl = shaded,
                state = { params:get('rev '..n) },
                action = function(v, t)
                    sc.slew(n, (t < 0.2) and 0.025 or t)
                    params:set('rev '..n, v)
                end,
            }
        end)
        do
            local off = wide and 6 or 4
            _params.rate = to.pattern(mpat, 'rate '..n, Grid.number, function()
                return {
                    x = wide and { 8, 15 } or { 3, 8 }, y = top, filtersame = true,
                    state = { params:get('rate '..n) + off },
                    action = function(v, t)
                        sc.slew(n, t)
                        params:set('rate '..n, v - off)
                    end,
                }
            end)
        end

        --local _cf_assign = { Grid.toggle(), Grid.toggle() }

        return function()
            --[[
            _cf_assign[1]{
                x = wide and 14 or 7, y = wide and top or bottom, 
                lvl = shaded,
                state = { params:get('crossfade assign '..n) == 2 and 1 or 0 },
                action = function(v)
                    if v == 1 then
                        params:set('crossfade assign '..n, 2)
                    elseif v == 0 then
                        params:set('crossfade assign '..n, 1)
                    end
                end
            }
            _cf_assign[2]{
                x = wide and 15 or 8, y = wide and top or bottom, 
                lvl = shaded,
                state = { params:get('crossfade assign '..n) == 3 and 1 or 0 },
                action = function(v)
                    if v == 1 then
                        params:set('crossfade assign '..n, 3)
                    elseif v == 0 then
                        params:set('crossfade assign '..n, 1)
                    end
                end
            }
            --]]

            for _, _param in pairs(_params) do _param() end
            
            if sc.lvlmx[n].play == 1 and sc.punch_in[sc.buffer[n]].recorded then
                _phase{ 
                    x = wide and { 1, 16 } or { 1, 8 }, y = top,
                    phase = sc.phase[n].rel, lvl = 4,
                }
            end
        end
    end

    local _view = wide and Components.grid.view()
    local _norns_view = Grid.number()
    
    local _voices = {}
    for i = 1, voices do
        _voices[i] = Voice(i)
    end

    local _patrec = PatternRecorder()

    return function()
        if wide then
            _view{
                x = 3, y = 1, lvl = 8,
                view = view,
                vertical = { vertical, function(v) vertical = v end },
                action = function(vertical, x, y)
                    if not vertical then norns_view = y end

                    nest.arc.make_dirty()
                    nest.screen.make_dirty()
                end
            }
        end
        _norns_view{
            x = 1, y = { 1, 4 }, lvl = 8,
            state = { 
                4 - norns_view + 1, 
                function(v) 
                    norns_view = 4 - v + 1 
                    nest.screen.make_dirty()
                end 
            }
        }

        
        for i, _voice in ipairs(_voices) do
            _voice{}
        end
        
        _patrec{
            x = 16, y = { 1, 8 }, pattern = pattern,
        }
    end
end

return App
