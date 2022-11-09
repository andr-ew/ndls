local function App(args)
    local varibright = args.varibright
    local wide = args.wide
    local tall = args.tall
    local shaded = { 4, 15 }
    local mid = varibright and 4 or 15
    local mid2 = varibright and 8 or 15

    local function Presets(args)
        local n = args.voice
        local hi = varibright and 15 or 0
        local lo = varibright and 0 or 15
        local top, bottom = n, n + voices

        local _presets = {}
        local set_preset = {}

        for b = 1, buffers do
            local id = 'preset '..n..' buffer '..b

            _presets[b] = Grid.number()
            set_preset[b] = multipattern.wrap_set(mpat, id, 
                wide and function(v)
                    params:set(id, v, true) 
                    params:lookup_param(id):bang()
                end or function(v)
                    local vv = v.x + (((3 - v.y + 1) - 1) * 3)

                    params:set(id, vv, true) 
                    params:lookup_param(id):bang()
                end
            )
        end
        local _fill = Grid.fill()
        local _fill2 = Grid.fill()
        local _fill3 = Grid.fill()

        return function()
            local b = sc.buffer[n]
            local recd = sc.punch_in:is_recorded(n)
            local sl = preset[n][b]

            if wide then
                _fill{ x = tall and 9 or 7, y = bottom, lvl = 8 }
                _fill2{ x = (tall and 9 or 7) + 4, y = bottom, lvl = 4 }
                _fill2{ x = (tall and 9 or 7) + 4 + 4, y = bottom, lvl = 4 }
                
                if recd then 
                    _presets[b]{
                        x = tall and { 9, 16 } or { 7, 15 }, 
                        y = bottom,
                        lvl = { lo, sc.phase[n].delta==0 and lo or hi },
                        filtersame = false,
                        state = { sl, set_preset[b] }
                    }
                end
            elseif view.track == n then
                if varibright then 
                    _fill{ x = { 5, 7 }, y = { 1, 3 }, lvl = 4 } 
                    _fill2{ x = 5, y = 1, lvl = 8 }
                end
                
                if recd then 
                    _presets[b]{
                        x = { 5, 7 }, y = { 1, 3 },
                        lvl = { lo, sc.phase[n].delta==0 and lo or hi },
                        filtersame = false,
                        state = {
                            { x = (sl-1) % 3 + 1, y = 3 - ((sl - 1) // 3 + 1) + 1 },
                            set_preset[b]
                        }
                    }
                end
            end
        end
    end

    local function Voice(n)
        local top, bottom = n, n + voices

        local _rec = to.pattern(mpat, 'rec '..n, Grid.toggle, function()
            return {
                x = 1, y = bottom, edge = 'falling',
                state = { params:get('rec '..n) },
                action = function(v, t)
                    if t < 0.5 then params:set('rec '..n, v)
                    else params:delta('clear '..n, 1) end
                end
            }
        end)
        local _play = to.pattern(mpat, 'play '..n, Grid.toggle, function()
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
                }
            }
        end) 

        local set_send = multipattern.wrap_set(mpat, 'send '..n, function(v)
            params:set('send '..n, v)
        end)
        local _send = Grid.toggle()

        local set_buffer = multipattern.wrap_set(mpat, 'buffer '..n, function(v)
            params:set('buffer '..n, v)
        end)
        local _buffer = Grid.number()

        local set_send = multipattern.wrap_set(mpat, 'send '..n, function(v)
            params:set('send '..n, v)
        end)
        local _send = Grid.toggle()

        local set_ret = multipattern.wrap_set(mpat, 'return '..n, function(v)
            params:set('return '..n, v)
        end)
        local _ret = Grid.toggle()

        local _phase = Components.grid.phase()
        local _rev = Grid.toggle()
        local _rate = Grid.number()
        local _loop = Grid.toggle()
        local _presets = Presets{ voice = n }

        return function()
            if sc.lvlmx[n].play == 1 and sc.punch_in:is_recorded(n) then
                _phase{ 
                    x = wide and { 6, 13 } or { 2, 8 }, 
                    y = wide and top or bottom, 
                    lvl = 4,
                    phase = reg.play:phase_relative(n, sc.phase[n].abs, 'fraction'),
                }
            end
            
            if wide then
                _rec()
                _play()

                --_loop{
                --    x = 2, y = bottom, lvl = shaded,
                --    state = {
                --        sc.punch_in:is_recorded(n) and (
                --            mparams:get(n, 'loop')
                --        ) or 0,
                --        function(v)
                --            mparams:set(n, 'loop', v)

                --            if sc.punch_in:is_recorded(n) then 
                --            elseif sc.punch_in:is_recorded(n) then
                --                local z = sc.buffer[n]

                --                --TODO: refactor reset call into sc.punch_in
                --                sc.punch_in:set(z, 0)
                --                preset:reset(n)
                --            end
                --        end
                --    },
                --}
                _buffer{
                    x = tall and { 3, 8 } or { 3, 6 }, y = bottom,
                    state = { params:get('buffer '..n), set_buffer }
                }
                _send{
                    x = wide and (tall and 15 or 14) or 7, y = wide and top or bottom, 
                    lvl = { 4, 15 },
                    state = { params:get('send '..n), set_send }
                }
                _ret{
                    x = wide and (tall and 16 or 15) or 8, y = wide and top or bottom, 
                    lvl = { 0, 15 },
                    state = { params:get('return '..n), set_ret }
                }
            end
            if wide or (view.page ~= MIX) then
                _rev{
                    x = wide and 5 or 1, y = wide and top or bottom, 
                    edge = 'falling', lvl = shaded,
                    state = { 
                        mparams:get(n, 'rev'),
                    },
                    action = function(v, t)
                        mparams:set(n, 'rate_slew', (t < 0.2) and 0.025 or t)
                        mparams:set(n, 'rev', v)
                    end,
                }
                do
                    local off = wide and 6 or 5
                    _rate{
                        x = wide and { 6, 13 } or { 2, 8 }, y = wide and top or bottom, 
                        filtersame = true,
                        state = {
                            mparams:get(n, 'rate') + off 
                        },
                        action = function(v, t)
                            mparams:set(n, 'rate_slew', t)
                            mparams:set(n, 'rate', v - off)
                        end,
                    }
                end
            end

            _presets()
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
            x = { 1, 4 }, y = { 1, voices }, lvl = { 1, mid2 },
            state = { 
                { y = voices - view.track + 1, x = view.page },
                function(v) 
                    view.track = voices - v.y + 1
                    view.page = v.x
                end 
            }
        }

        for i, _voice in ipairs(_voices) do _voice() end

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
