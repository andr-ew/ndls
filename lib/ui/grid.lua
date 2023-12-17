local shaded = { 4, 15 }

local function Preset(args)
    local varibright = args.varibright
    local wide = args.wide
    local tall = args.tall
    local n = args.voice
    local hi = varibright and 15 or 0
    local lo = varibright and 0 or 15
    local top, bottom = n, n + voices

    local set_preset = function(b, v)
        local id = 'preset '..n..' buffer '..b

        local retrigger = true
        set_param(id, v, retrigger)
    end

    local _fills = Grid.fills()
    local _fill1 = Grid.fill()
    local _fill2 = Grid.fill()
    local _fill3 = Grid.fill()

    local _preset = Grid.integer()

    return function()
        local b = sc.buffer[n]
        local recd = sc.punch_in:is_recorded(n)
        local sl = preset[n][b]
        
        if wide then
            _fill1{ x = wide and (tall and 9 or 7) or 5, y = bottom, level = 8 }
            _fill2{ x = wide and ((tall and 9 or 7) + 3) or (5 + 2), y = bottom, level = 4 }
            _fill3{ x = wide and ((tall and 9 or 7) + 3 + 3) or -1, y = bottom, level = 4 }
            
            if recd then 
                _preset{
                    x = (tall and 9 or 7),
                    y = bottom,
                    size = 7,
                    levels = { lo, sc.phase[n].delta==0 and lo or hi },
                    state = { sl, set_preset, b }
                }
            end
        elseif view.track == n then
            local x, y, wrap, size = 3, 1, 3, 9

            if varibright then 
                _fills{ x = x, y = y, wrap = wrap, size = size, level = 4 } 
                _fill1{ x = x, y = y, lvl = 6 }
            end
            
            if recd then 
                _preset{
                    x = x, y = y, wrap = wrap, size = size,
                    levels = { lo, sc.phase[n].delta==0 and lo or hi },
                    state = { sl, set_preset, b }
                }
            end
        end
    end
end

local function Buffer(args)
    local clk
    local downstate

    if args.wide then
        local _buf = Grid.integer()

        return function(props)
            local input = function(n, z)
                if z == 1 then
                    if clk then clock.cancel(clk) end
                    clk = clock.run(function() 
                        clock.sleep(0.5)

                        local b = n
                        view.modal = 'buffer'
                        view.modal_index = props.voice
                        crops.dirty.screen = true
                        crops.dirty.grid = true
                    end)
                else
                    clock.cancel(clk)
                    view.modal = 'none'
                end
            end

            _buf{
                x = props.x, y = props.y, size = props.size,
                levels = { 
                    0, 
                    (view.modal == 'buffer' and view.modal_index == props.voice) and 4 or 15 
                },
                state = props.state,
                input = input,
            }
        end
    else
        local _buf = Components.grid.integerbinary()

        return function(props)
            local input = function(n, z)
                if z == 1 then
                    if clk then clock.cancel(clk) end
                    clk = clock.run(function() 
                        clock.sleep(0.5)

                        local b = props.state[1]
                        view.modal = 'buffer'
                        view.modal_index = props.voice
                        crops.dirty.screen = true
                        crops.dirty.grid = true
                        downstate = b
                    end)
                else
                    clock.cancel(clk)
                    if downstate then props.state[2](downstate) end
                    downstate = nil
                    view.modal = 'none'
                end
            end

            _buf{
                x = props.x, y = props.y, size = props.size, 
                levels = { 
                    0, 
                    (view.modal == 'buffer' and view.modal_index == props.voice) and 4 or 15 
                },
                edge = 'falling',
                state = props.state,
                input = input,
            }
        end
    end
end

local function Voice(args)
    local n = args.voice
    local varibright = args.varibright
    local wide = args.wide
    local tall = args.tall
    local top, bottom = n, n + voices

    local _rec = Grid.toggle()
    local _play = Grid.toggle()
    local _not_playing = Grid.fill()
    local _buffer = Buffer{ wide = wide }
    local _phase = Components.grid.phase()
    local _rev = Components.grid.togglehold()
    local _rate = Components.grid.integerglide()
    local _loop = Grid.toggle()
    local _send = Grid.toggle()
    local _ret = Grid.toggle()

    local _preset = Preset{ 
        voice = n, varibright = varibright, wide = wide, tall = tall,
    }

    return function()
        local rate_x = wide and 8 or 4
        local rate_size = wide and 7 or 5
        local b = sc.buffer[n]
        local recorded = sc.punch_in[b].recorded
        local recording = sc.punch_in[b].recording

        _rec{
            x = 1, y = bottom,
            state = { params:get('rec '..n), set_param, 'rec '..n },
        }
        if recorded or recording then
            _play{
                x = 2, y = bottom, levels = shaded,
                state = { recorded and params:get('play '..n) or 0, set_param, 'play '..n }
            }
        else
            _not_playing{ x = 2, y = bottom, level = shaded[1] }
        end

        if not (crops.mode == 'input' and recording) then
            _buffer{
                x = wide and 3 or 6, y = wide and bottom or top, 
                size = wide and (tall and 6 or 4) or 2,
                wide = wide,
                voice = n,
                state = { params:get('buffer '..n), set_param, 'buffer '..n }
            }
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
                set_mparam(
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
                    function(v) set_mparam(n, 'rate', v - off) end 
                },
                hold_action = function(t) 
                    set_mparam(n, 'rate_slew', t * (1.3 + (math.random() * 0.5))) 
                end,
            }
        end
        if recorded then
            _loop{
                x = wide and 15 or 8, y = top, levels = shaded,
                state = of_mparam(n, 'loop'),
            }
        end
        if wide or view.track == n then
            _send{
                x = wide and (tall and 16 or 14) or 4, 
                y = wide and (tall and top or bottom) or 4, 
                levels = { 2, 15 },
                state = { params:get('send '..n), set_param, 'send '..n }
            }
            _ret{
                x = wide and (tall and 16 or 15) or 5, 
                y = wide and bottom or 4, 
                levels = { 2, 15 },
                state = { params:get('return '..n), set_param, 'return '..n }
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

    local small_page_focus = arc_connected or (not wide)

    local _track_focus = Grid.integer()
    local _page_focus = small_page_focus and Grid.momentary() or Grid.integer()

    local _arc_focus = wide and arc_connected and Components.grid.arc_focus()

    local _voices = {}
    for i = 1, voices do
        _voices[i] = Voice{
            voice = i, varibright = varibright, wide = wide, tall = tall,
        }
    end

    -- local _patrec = PatternRecorder()

    local _patrecs = {}
    for i = 1,16 do _patrecs[i] = Produce.grid.pattern_recorder() end

    local next_page = 0
    local prev_page = 0

    return function()
        _track_focus{
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
            _page_focus{
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
            
        if small_page_focus then
            _page_focus{
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
                _patrecs[i]{
                    x = tall and i or 16, 
                    y = tall and 16 or i, 
                    pattern = pattern[i], 
                    varibright = varibright
                }
            end
        else
            _patrecs[1]{
                x = 2, y = 2, 
                pattern = pattern[1], 
                varibright = varibright
            }
            _patrecs[2]{
                x = 2, y = 3, 
                pattern = pattern[2], 
                varibright = varibright
            }
            _patrecs[3]{
                x = 2, y = 4, 
                pattern = pattern[3], 
                varibright = varibright
            }
            _patrecs[4]{
                x = 3, y = 4, 
                pattern = pattern[4], 
                varibright = varibright
            }
        end

        if crops.mode == 'redraw' and crops.device == 'grid' then 
            freeze_patrol:ping('grid')
        end
    end
end

return App
