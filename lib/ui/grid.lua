local shaded = { 4, 15 }

local function Preset(args)
    local varibright = args.varibright
    local wide = args.wide
    local tall = args.tall
    local n = args.voice
    local hi = varibright and 15 or 0
    local lo = varibright and 0 or 15
    local top, bottom = n, n + voices

    local set_preset = multipattern.wrap_set(mpat, 'preset '..n, 
        function(b, v)
            local id = 'preset '..n..' buffer '..b
            params:set(id, v, true) 
            params:lookup_param(id):bang()
        end
    )

    return function()
        local b = sc.buffer[n]
        local recd = sc.punch_in:is_recorded(n)
        local sl = preset[n][b]
        
        if wide then
            _grid.fill{ x = wide and (tall and 9 or 7) or 5, y = bottom, level = 8 }
            _grid.fill{ x = wide and ((tall and 9 or 7) + 3) or (5 + 2), y = bottom, level = 4 }
            _grid.fill{ x = wide and ((tall and 9 or 7) + 3 + 3) or -1, y = bottom, level = 4 }
            
            if recd then 
                _grid.integer{
                    x = (tall and 9 or 7),
                    y = bottom,
                    size = wide and 7 or 4,
                    levels = { lo, sc.phase[n].delta==0 and lo or hi },
                    state = { sl, set_preset, b }
                }
            end
        elseif view.track == n then
            local x, y, wrap, size = 3, 1, 3, 9

            if varibright then 
                _grid.fills{ x = x, y = y, wrap = wrap, size = size, level = 4 } 
                _grid.fill{ x = x, y = y, lvl = 8 }
            end
            
            if recd then 
                _grid.integer{
                    x = x, y = y, wrap = wrap, size = size,
                    levels = { lo, sc.phase[n].delta==0 and lo or hi },
                    state = { sl, set_preset, b }
                }
            end
        end
    end
end

local function Voice(args)
    local n = args.voice
    local varibright = args.varibright
    local wide = args.wide
    local tall = args.tall
    local top, bottom = n, n + voices

    local set_rec = multipattern.wrap_set(mpat, 'rec '..n, function(v)
        params:set('rec '..n, v)
    end)
    local hold_rec = function() 
        params:delta('clear '..n, 1) 
    end

    local set_play = multipattern.wrap_set(mpat, 'play '..n, function(v)
        params:set('play '..n, v)
    end)
    local set_buffer = multipattern.wrap_set(mpat, 'buffer '..n, function(v)
        params:set('buffer '..n, v)
    end)
    local set_send = multipattern.wrap_set(mpat, 'send '..n, function(v)
        params:set('send '..n, v)
    end)
    local set_ret = multipattern.wrap_set(mpat, 'return '..n, function(v)
        params:set('return '..n, v)
    end)

    local _phase = Components.grid.phase()
    local _rev = Components.grid.togglehold()
    local _rate = Components.grid.integerglide()

    local _preset = Preset{ 
        voice = n, varibright = varibright, wide = wide, tall = tall,
    }

    return function()
        local rate_x = wide and 8 or 4
        local rate_size = wide and 7 or 5
        local b = sc.buffer[n]
        local recorded = sc.punch_in[b].recorded
        local recording = sc.punch_in[b].recording

        _grid.toggle{
            x = 1, y = bottom,
            state = { params:get('rec '..n), set_rec },
        }
        if recorded or recording then
            _grid.toggle{
                x = 2, y = bottom, levels = shaded,
                state = { recorded and params:get('play '..n) or 0, set_play }
            }
        else
            _grid.fill{ x = 2, y = bottom, level = shaded[1] }
        end

        if not (crops.mode == 'input' and recording) then
            if wide then
                _grid.integer{
                    x = 3, y = bottom,
                    size = tall and 6 or 4,
                    state = { params:get('buffer '..n), set_buffer }
                }
            else
                _routines.grid.integerbinary{
                    x = 6, y = top, size = 2,
                    state = { params:get('buffer '..n), set_buffer }
                }
            end
        end
        
        if sc.lvlmx[n].play == 1 and recorded then
            _phase{ 
                x = rate_x, 
                y = wide and top or bottom, 
                size = rate_size,
                level = 4,
                phase = reg.play:phase_relative(n, sc.phase[n].abs, 'fraction'),
            }
        end
        _rev{
            x = wide and 7 or 3, y = wide and top or bottom, 
            levels = shaded,
            state = of_mparam(n, 'rev'),
            hold_time = 0,
            hold_action = function(t)
                mparams:set(
                    n, 'rate_slew', 
                    (t < 0.2) and 0.025 or t * (1.3 + (math.random() * 0.5))
                )
            end,
        }
        do
            local off = wide and 5 or 4
            _rate{
                x = rate_x, y = wide and top or bottom, size = rate_size,
                state = { 
                    mparams:get(n, 'rate') + off, 
                    function(v) mparams:set(n, 'rate', v - off) end 
                },
                hold_action = function(t) 
                    mparams:set(n, 'rate_slew', t * (1.3 + (math.random() * 0.5))) 
                end,
            }
        end
        if recorded then
            _grid.toggle{
                x = wide and 15 or 8, y = top, levels = shaded,
                state = of_mparam(n, 'loop'),
            }
        end
        if wide then
            _grid.toggle{
                x = tall and 16 or 14, y = tall and top or bottom, 
                levels = { 2, 15 },
                state = { params:get('send '..n), set_send }
            }
            _grid.toggle{
                x = tall and 16 or 15, y = bottom, 
                levels = { 2, 15 },
                state = { params:get('return '..n), set_ret }
            }
        end

        _preset()
    end
end

local function App(args)
    local varibright = args.varibright
    local wide = args.wide
    local tall = args.tall
    local mid = varibright and 4 or 15
    local low_shade = varibright and { 2, 8 } or { 0, 15 }
    local mid_shade = varibright and { 4, 8 } or { 0, 15 }

    local _voices = {}
    for i = 1, voices do
        _voices[i] = Voice{
            voice = i, varibright = varibright, wide = wide, tall = tall,
        }
    end

    local _patrec = PatternRecorder()

    local _arc_focus = wide and arc_connected and Components.grid.arc_focus()

    local next_page = 0
    local prev_page = 0

    return function()
        _grid.integer{
            x = 1, y = 1, size = voices, flow = 'down',
            levels = low_shade,
            state = { 
                view.track, 
                function(v) 
                    view.track = v
                    crops.dirty.screen = true 
                    crops.dirty.grid = true
                end 
            }
        }

        if _arc_focus then
            --TODO: refactor to use states more correctly
            _arc_focus{
                x = 3, y = 1, levels = low_shade,
                view = arc_view, tall = tall,
                vertical = { arc_vertical, function(v) arc_vertical = v end },
                action = function(vertical, x, y)
                    if not vertical then view.track = y end

                    crops.dirty.screen = true 
                    crops.dirty.grid = true
                end
            }
            -- _grid.momentary{
            --     x = 2, y = 3, levels = mid_shade,
            --     state = { prev_page, function(v) 
            --         prev_page = v
            --         crops.dirty.grid = true

            --         if v>0 then
            --             view.page = util.wrap(view.page - 1, 1, #page_names)
            --             crops.dirty.screen = true
            --         end
            --     end }
            -- }
        elseif wide then
            _grid.integer{
                y = 1, 
                x = _arc_focus and 2 or 3, 
                flow = _arc_focus and 'down' or 'right',
                size = #page_names,
                levels = shaded,
                state = { 
                    view.page, 
                    function(v) 
                        view.page = v 

                        crops.dirty.screen = true 
                        crops.dirty.grid = true
                    end 
                }
            }
        end
            
        if arc_connected or (not wide) then
            _grid.momentary{
                x = 2, y = 1, levels = mid_shade,
                state = { next_page, function(v) 
                    next_page = v
                    crops.dirty.grid = true

                    if v>0 then
                        view.page = util.wrap(view.page + 1, 1, #page_names)
                        crops.dirty.screen = true
                    end
                end }
            }
        end

        for i, _voice in ipairs(_voices) do _voice() end

        if wide then
            for i = 1,(tall and 16 or 8) do
                _patrec{
                    x = tall and i or 16, 
                    y = tall and 16 or i, 
                    pattern = pattern[i], 
                    varibright = varibright
                }
            end
        else
            for i = 1,4 do
                _patrec{
                    x = 2 + i - 1, y = 4, 
                    pattern = pattern[i], 
                    varibright = varibright
                }
            end
            _patrec{
                x = 2, y = 2, 
                pattern = pattern[5], 
                varibright = varibright
            }
            _patrec{
                x = 2, y = 3, 
                pattern = pattern[6], 
                varibright = varibright
            }
        end

        if crops.mode == 'redraw' and crops.device == 'grid' then 
            freeze_patrol:ping('grid')
        end
    end
end

return App
