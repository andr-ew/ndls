local function App(args)
    local varibright = args.varibright
    local wide = args.wide
    local tall = args.tall
    local shaded = varibright and { 4, 15 } or { 0, 15 }
    local mid = varibright and 4 or 15
    local mid2 = varibright and 8 or 15

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
        do
            _params.buffer = wide and to.pattern(mpat, 'buffer '..n, Grid.number, function()
                return {
                    x = tall and { 3, 8 } or { 3, 6 }, y = bottom,
                    state = {
                        sc.buffer[n],
                        function(v)
                            sc.buffer:set(n, v)

                            nest.arc.make_dirty()
                            nest.screen.make_dirty()
                        end
                    }
                }
            end) or Components.grid.buffer64{ voice = n, x = { 3, 4 }, y = bottom }
        end
        local function Slices(args)
            local n = args.voice

            local _slices = {}

            for b = 1, buffers do
                _slices[b] = to.pattern(mpat, 'slice '..n..' '..b, Grid.number, function()
                    return {
                        x = tall and { 9, 14 } or (wide and { 7, 15 } or { 5, 8 }), 
                        y = bottom,
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
                _fill{ x = wide and 7 or 5, y = bottom, lvl = 4 }

                if sc.punch_in[b].recorded then
                    _slices[b]()
                end
            end
        end
        _params.slices = Slices{ voice = n }
        if wide then
            _params.send = to.pattern(mpat, 'send '..n, Grid.toggle, function()
                return {
                    x = tall and 15 or 14, y = top, lvl = { 4, 15 },
                    state = of.param('send '..n),
                }
            end)
            _params.ret = to.pattern(mpat, 'return '..n, Grid.toggle, function()
                return {
                    x = tall and 16 or 15, y = top, lvl = { 0, 15 },
                    state = of.param('return '..n),
                }
            end)
        end
        _params.rev = to.pattern(mpat, 'rev '..n, Grid.toggle, function()
            return {
                x = wide and 5 or 2, y = top, edge = 'falling', lvl = shaded,
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
                    x = wide and { 6, 13 } or { 3, 7 }, y = top, filtersame = true,
                    state = { params:get('rate '..n) + off },
                    action = function(v, t)
                        sc.slew(n, t)
                        params:set('rate '..n, v - off)
                    end,
                }
            end)
        end

        return function()
            if varibright then
                if sc.lvlmx[n].play == 1 and sc.punch_in[sc.buffer[n]].recorded then
                    _phase{ 
                        x = wide and { 6, 13 } or { 3, 7 }, y = top, lvl = 4,
                        phase = reg.play:phase_relative(n, sc.phase[n].abs, 'fraction'),
                    }
                end
            end

            for _, _param in pairs(_params) do _param() end
        end
    end

    local _view = Grid.number()
    
    local _voices = {}
    for i = 1, voices do
        _voices[i] = Voice(i)
    end

    local _patrec = PatternRecorder()

    return function()
        if wide then
            _view{
                x = { 1, 4 }, y = { 1, voices }, lvl = mid2,
                state = { 
                    { y = voices - view.track + 1, x = view.page },
                    function(v) 
                        view.track = voices - v.y + 1
                        view.page = v.x
                    end 
                }
            }
        else
            _view{
                x = 1, y = { 1, voices }, lvl = mid2,
                state = { 
                    voices - view.track + 1, 
                    function(v) 
                        norns_view = voices - v + 1 
                        nest.screen.make_dirty()
                    end 
                }
            }
        end

        
        for i, _voice in ipairs(_voices) do
            _voice{}
        end
        
        _patrec{
            x = tall and { 1, 16 } or (wide and 16 or 8), 
            y = tall and 16 or (wide and { 1, 8 } or { 1, 4 }), 
            state = { pattern_states.main },
            pattern = pattern, varibright = varibright
        }
    end
end

return App
