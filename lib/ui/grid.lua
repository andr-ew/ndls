local function App(args)
    local varibright = args.varibright
    local wide = args.wide
    local tall = args.tall
    local shaded = { 4, 15 }
    local mid = varibright and 4 or 15
    local low_shade = varibright and { 2, 8 } or 15
    local mid_shade = varibright and { 4, 8 } or 15

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

            _fill{ x = wide and (tall and 9 or 7) or -1, y = bottom, lvl = 8 }
            _fill2{ x = wide and ((tall and 9 or 7) + 3) or -1, y = bottom, lvl = 4 }
            _fill2{ x = wide and ((tall and 9 or 7) + 3 + 3) or -1, y = bottom, lvl = 4 }
            
            if recd then 
                _presets[b]{
                    x = wide and (tall and { 9, 15 } or { 7, 13 }) or { -2, -1 }, 
                    y = bottom,
                    lvl = { lo, sc.phase[n].delta==0 and lo or hi },
                    filtersame = false,
                    state = { sl, set_preset[b] }
                }
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
            local rate_x = wide and { 8, 14 } or { 3, 7 }

            if sc.lvlmx[n].play == 1 and sc.punch_in:is_recorded(n) then
                _phase{ 
                    x = rate_x, 
                    y = wide and top or bottom, 
                    lvl = 4,
                    phase = reg.play:phase_relative(n, sc.phase[n].abs, 'fraction'),
                }
            end
        
            _rec()
            _play()

            _buffer{
                x = tall and { 3, 8 } or { 3, 6 }, y = bottom,
                state = { params:get('buffer '..n), set_buffer }
            }
            _rev{
                x = wide and 7 or 3, y = top, 
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
                local off = wide and 5 or 4
                _rate{
                    x = rate_x, y = top, 
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
            if wide then
                _send{
                    x = tall and 16 or 14, y = tall and top or bottom, 
                    lvl = { 2, 15 },
                    state = { params:get('send '..n), set_send }
                }
                _ret{
                    x = tall and 16 or 15, y = bottom, 
                    lvl = { 2, 15 },
                    state = { params:get('return '..n), set_ret }
                }
                _loop{
                    x = 15, y = top, lvl = shaded,
                    state = {
                        sc.punch_in:is_recorded(n) and (
                            mparams:get(n, 'loop')
                        ) or 0,
                        function(v)
                            mparams:set(n, 'loop', v)

                            --if sc.punch_in:is_recorded(n) then 
                            --elseif sc.punch_in:is_recorded(n) then
                            --    local z = sc.buffer[n]

                            --    --TODO: refactor reset call into sc.punch_in
                            --    sc.punch_in:set(z, 0)
                            --    preset:reset(n)
                            --end
                        end
                    },
                }
            end

            _presets()
        end
    end

    local _voices = {}
    for i = 1, voices do
        _voices[i] = Voice(i)
    end

    local _patrec = PatternRecorder()
    local _patrec2 = not wide and PatternRecorder()

    local _track_focus = Grid.number()
    local _arc_focus = (wide and (not tall) and arc_connected) and Components.grid.arc_focus()
    local _page_focus = (wide and not _arc_focus) and Grid.number()


    return function()
        _track_focus{
            x = 1, y = { 1, voices }, lvl = low_shade,
            state = { 
                voices - view.track + 1, 
                function(v) 
                    view.track = voices - v + 1 
                    nest.screen.make_dirty()
                end 
            }
        }
        if _arc_focus then
            _arc_focus{
                x = 3, y = 1, lvl = low_shade,
                view = arc_view, tall = tall,
                vertical = { arc_vertical, function(v) arc_vertical = v end },
                action = function(vertical, x, y)
                    if not vertical then view.track = y end

                    nest.arc.make_dirty()
                    nest.screen.make_dirty()
                end
            }
        elseif wide then
            _page_focus{
                y = 1, x = { 2, 2 + #page_names - 1 }, lvl = mid_shade,
                state = { 
                    view.page//1, 
                    function(v) 
                        view.page = v 
                        nest.screen.make_dirty()
                    end 
                }
            }
        end

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
