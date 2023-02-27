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
        wide and function(b, v)
            local id = 'preset '..n..' buffer '..b
            params:set(id, v, true) 
            params:lookup_param(id):bang()
        end or function(b, v)
            local vv = v.x + (((3 - v.y + 1) - 1) * 3)
            local id = 'preset '..n..' buffer '..b

            params:set(id, vv, true) 
            params:lookup_param(id):bang()
        end
    )

    return function()
        local b = sc.buffer[n]
        local recd = sc.punch_in:is_recorded(n)
        local sl = preset[n][b]

        _grid.fill{ x = wide and (tall and 9 or 7) or 5, y = bottom, level = 8 }
        _grid.fill{ x = wide and ((tall and 9 or 7) + 3) or (5 + 2), y = bottom, level = 4 }
        _grid.fill{ x = wide and ((tall and 9 or 7) + 3 + 3) or -1, y = bottom, level = 4 }
        
        if recd then 
            _grid.integer{
                x = wide and (tall and 9 or 7) or 5,
                y = bottom,
                size = wide and 7 or 4,
                levels = { lo, sc.phase[n].delta==0 and lo or hi },
                state = { sl, set_preset, b }
            }
        end
    end
end

--TODO: probably makes sense to move these to ui/components

local function Togglehold()
    local downtime = nil

    return function(props)
        props.edge = 'falling'
        props.input = function(z)
            if z==1 then
                downtime = util.time()
            elseif z==0 then
                local heldtime = util.time() - downtime

                if heldtime > (props.hold_time or 0.5) then
                    if props.hold_action then props.hold_action(heldtime) end
                end

                downtime = nil --probably extraneous
            end
        end

        _grid.toggle(props)
    end
end

local function Integerglide()
    local downtime = nil
    local held = false

    return function(props)
        if crops.mode == 'input' and crops.device == 'grid' then 
            local x, y, z = table.unpack(crops.args) 
            local n = _grid.util.xy_to_index(props, x, y)

            if n then 
                local old = crops.get_state(props.state)
                local new = n

                if z==1 then
                    if not held then downtime = util.time() end
                    held = true

                    if new ~= old then
                        local heldtime = util.time() - downtime

                        if props.hold_action then props.hold_action(heldtime) end
                        crops.set_state(props.state, new) 
                        
                        held = false
                    end
                end
            end
        elseif crops.mode == 'redraw' then
            _grid.integer(props)
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
    local _rev = Togglehold()
    local _rate = Integerglide()

    local _preset = Preset{ 
        voice = n, varibright = varibright, wide = wide, tall = tall,
    }

    return function()
        local rate_x = wide and 8 or 3
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

        if wide then
            _grid.integer{
                x = 3, y = bottom,
                size = tall and 6 or 4,
                state = { params:get('buffer '..n), set_buffer }
            }
        else
            --TODO: binary buffer selection
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
            x = wide and 7 or 3, y = top, 
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
                x = rate_x, y = top, size = 7,
                state = { 
                    mparams:get(n, 'rate') + off, 
                    function(v) mparams:set(n, 'rate', v - off) end 
                },
                hold_action = function(t) 
                    mparams:set(n, 'rate_slew', t * (1.3 + (math.random() * 0.5))) 
                end,
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
            if recorded then
                _grid.toggle{
                    x = 15, y = top, levels = shaded,
                    state = of_mparam(n, 'loop'),
                }
            end
        end

        _preset()
    end
end

local function App(args)
    local varibright = args.varibright
    local wide = args.wide
    local tall = args.tall
    local mid = varibright and 4 or 15
    local low_shade = varibright and { 2, 8 } or 15
    local mid_shade = varibright and { 4, 8 } or 15

    local _voices = {}
    for i = 1, voices do
        _voices[i] = Voice{
            voice = i, varibright = varibright, wide = wide, tall = tall,
        }
    end

    local _patrec = PatternRecorder()
    local _patrec2 = not wide and PatternRecorder()

    local _arc_focus = (wide and (not tall) and arc_connected) and Components.grid.arc_focus()

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
        elseif wide then
            _grid.integer{
                y = 1, x = 2, size = #page_names,
                levels = mid_shade,
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

        for i, _voice in ipairs(_voices) do _voice() end

        for i = 1,(tall and 16 or (wide and 8 or 4)) do
            _patrec{
                x = tall and i or (wide and 16 or 8), 
                y = tall and 16 or i, 
                pattern = pattern[i], 
                varibright = varibright
            }
        end

        if crops.mode == 'redraw' and crops.device == 'grid' then 
            freeze_patrol:ping('grid')
        end
    end
end

return App
