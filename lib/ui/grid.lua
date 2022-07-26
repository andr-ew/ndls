local function App(args)
    local varibright = args.varibright
    local wide = args.wide
    local tall = args.tall
    local shaded = { 4, 15 }
    local mid = varibright and 4 or 15
    local mid2 = varibright and 8 or 15

    local function Voice(n)
        local top, bottom = n, n + voices

        local _phase = Components.grid.phase()
        
        local _params = {}
        _params.rec = to.pattern(mpat, 'rec '..n, Grid.toggle, function()
            return {
                x = 1, y = bottom, edge = 'falling',
                state = { params:get('rec '..n) },
                action = function(v, t)
                    if t < 0.5 then params:set('rec '..n, v)
                    else params:delta('clear '..n, 1) end
                end
            }
        end)
        _params.loop = to.pattern(mpat, 'loop '..n, Grid.toggle, function()
            return {
                x = 2, y = bottom, lvl = shaded,
                state = {
                    sc.punch_in[sc.buffer[n]].recorded and params:get('loop '..n) or 0,
                    function(v)
                        local recorded = sc.punch_in[sc.buffer[n]].recorded
                        local recording = sc.punch_in[sc.buffer[n]].recording

                        if recorded then 
                            params:set('loop '..n, v)
                        elseif recording then
                            local z = sc.buffer[n]
                            params:set('loop '..n, v)

                            --TODO: refactor reset call into sc.punch_in
                            sc.punch_in:set(z, 0)
                            sc.slice:reset(n)
                        end
                    end
                },
            }
        end)
        do
            _params.buffer = to.pattern(mpat, 'buffer '..n, Grid.number, function()
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
            end)
        end
        local function Slices(args)
            local n = args.voice

            local _slices = {}

            for b = 1, buffers do
                _slices[b] = to.pattern(mpat, 'slice '..n..' '..b, Grid.number, function()
                    local sl = sc.slice[n][b]
                    local hi = varibright and 15 or 0
                    local lo = varibright and 0 or 15

                    return {
                        x = tall and { 9, 16 } or (wide and { 7, 15 } or { 5, 7 }), 
                        y = wide and bottom or { 1, 3 },
                        lvl = { lo, sc.phase[n].delta==0 and lo or hi },
                        filtersame = false,
                        state = wide and {
                            sl,
                            function(v)
                                sc.slice:set(n, b, v)

                                nest.arc.make_dirty()
                                nest.screen.make_dirty()
                            end
                        } or {
                            { x = (sl-1) % 3 + 1, y = 3 - ((sl - 1) // 3 + 1) + 1 },
                            function(v)
                                local vv = v.x + (((3 - v.y + 1) - 1) * 3)

                                sc.slice:set(n, b, vv)

                                nest.arc.make_dirty()
                                nest.screen.make_dirty()
                            end
                        }
                    }
                end)
            end
            local _fill = Grid.fill()
            local _fill2 = not wide and Grid.fill()

            return function()
                local b = sc.buffer[n]
                local recd = sc.punch_in[b].recorded

                if wide then
                    _fill{ x = tall and 9 or 7, y = bottom, lvl = 4 }
                    
                    if recd then _slices[b]() end
                elseif view.track == n then
                    if varibright then 
                        _fill{ 
                            x = { 5, 7 }, y = { 1, 3 }, lvl = 4 
                        } 
                        _fill2{ x = 5, y = 1, lvl = 8 }
                    end
                    
                    if recd then _slices[b]() end
                end
            end
        end
        _params.slices = Slices{ voice = n }
        _params.send = to.pattern(mpat, 'send '..n, Grid.toggle, function()
            return {
                x = wide and (tall and 15 or 14) or 7, y = wide and top or bottom, 
                lvl = { 4, 15 },
                state = of.param('send '..n),
            }
        end)
        _params.ret = to.pattern(mpat, 'return '..n, Grid.toggle, function()
            return {
                x = wide and (tall and 16 or 15) or 8, y = wide and top or bottom, 
                lvl = { 0, 15 },
                state = of.param('return '..n),
            }
        end)
        _params.rev = to.pattern(mpat, 'rev '..n, Grid.toggle, function()
            return {
                x = wide and 5 or 1, y = wide and top or bottom, 
                edge = 'falling', lvl = shaded,
                state = { params:get('rev '..n) },
                action = function(v, t)
                    sc.slew(n, (t < 0.2) and 0.025 or t)
                    params:set('rev '..n, v)
                end,
            }
        end)
        do
            local off = wide and 6 or 5
            _params.rate = to.pattern(mpat, 'rate '..n, Grid.number, function()
                return {
                    x = wide and { 6, 13 } or { 2, 8 }, y = wide and top or bottom, 
                    filtersame = true,
                    state = { params:get('rate '..n) + off },
                    action = function(v, t)
                        sc.slew(n, t)
                        params:set('rate '..n, v - off)
                    end,
                }
            end)
        end

        return function()
            if sc.lvlmx[n].play == 1 and sc.punch_in[sc.buffer[n]].recorded then
                if (wide) or (view.page ~= 1) then
                    _phase{ 
                        x = wide and { 6, 13 } or { 2, 8 }, 
                        y = wide and top or bottom, 
                        lvl = 4,
                        phase = reg.play:phase_relative(n, sc.phase[n].abs, 'fraction'),
                    }
                end
            end
            
            if wide then
                for _, _param in pairs(_params) do _param() end
            else
                if view.page == 1 then
                    _params.rec()
                    _params.loop()
                    _params.buffer()
                    _params.send()
                    _params.ret()
                else
                    _params.rev()
                    _params.rate()
                end

                _params.slices()
            end
        end
    end

    local _view = Grid.number()
    
    local _voices = {}
    for i = 1, voices do
        _voices[i] = Voice(i)
    end

    local _patrec = PatternRecorder()
    local _patrec2 = not wide and PatternRecorder()

    return function()
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

        
        for i, _voice in ipairs(_voices) do
            _voice{}
        end
        

        if wide then
            _patrec{
                x = tall and { 1, 16 } or 16, 
                y = tall and 16 or { 1, 8 }, 
                state = { pattern_states.main },
                pattern = pattern, varibright = varibright
            }
        else
            local p = pattern
            local st = pattern_states.main
            _patrec{
                x = 8, y = { 1, 4 },
                pattern = { p[1], p[2], p[3], p[4] }, 
                state = {{ st[1], st[2], st[3], st[4] }},
                varibright = varibright
            }
            _patrec2{
                x = { 5, 7 }, y = 4,
                pattern = { p[5], p[6], p[7] }, 
                state = {{ st[5], st[6], st[7] }}, 
                varibright = varibright
            }
        end

        if nest.grid.is_drawing() then
            freeze_patrol:ping('grid')
        end
    end
end

return App
