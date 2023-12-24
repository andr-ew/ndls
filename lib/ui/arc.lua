local function Gain()
    local _gain = Arc.control()
    local _fill = Arc.control()

    return function(props) 
        local n = props.voice
        local id = 'gain '..n
        local xx = { 42 - 4, 42 + 16 + 3 }

        _gain{
            -- n = tonumber(arc_vertical and n or x),
            n = props.n,
            sensitivity = 0.5, 
            controlspec = params:lookup_param(id).controlspec,
            state = { params:get(id), params.set, params, id },
            levels = { 0, props.levels[1], props.levels[1] },
            -- x = { 33, 33 },
            x = xx,
        }
        if crops.mode == 'redraw' then
            _fill{
                -- n = tonumber(arc_vertical and n or x),
                n = props.n,
                controlspec = params:lookup_param(id).controlspec,
                state = { 0 },
                levels = { 0, 0, props.levels[2] },
                -- x = { 33, 33 },
                x = xx,
            }
        end
    end
end

local function Cut()
    local _filt = Components.arc.filter()
    local _cutoff = Arc.control()

    return function(props) 
        local n = props.voice

        if crops.mode == 'input' then
            _cutoff{
                -- n = tonumber(arc_vertical and n or x),
                n = props.n,
                levels = props.levels,
                x = { 42, 24+64 }, sensitivity = 0.25, 
                state = of_mparam(n, 'cut'),
                controlspec = mparams:get_controlspec('cut'),
            }
        end
        _filt{
            -- n = tonumber(arc_vertical and n or x),
            n = props.n,
            levels = props.levels,
            x = { 42, 24+64 },
            type = get_mparam(n, 'type'),
            cut = get_mparam(n, 'cut'),
            controlspec = mparams:get_controlspec('cut'),
        }
    end
end

local function Voice()
    local _gain = Gain()
    local _cut = Patcher.arc.destination(Cut())
    local _st = Patcher.arc.destination(Components.arc.st())
    local _len = Patcher.arc.destination(Components.arc.len())

    --TODO: arc2 layout
    return function(props)
        local n = props.voice

        if arc_view[n][1] > 0 then
            _gain{ 
                n = tonumber(arc_vertical and n or 1),
                voice = n,
                levels = { 4, 15 },
                rotated = rotated,
            }
        end
        if arc_view[n][2] > 0 then
            _cut(mparams:get_id(n, 'cut'), active_src, { 
                n = tonumber(arc_vertical and n or 2),
                voice = n,
                levels = { 4, 15 },
                rotated = rotated,
            })
        end
        
        local b = sc.buffer[n]
        if arc_view[n][3] > 0 then
            _st(wparams:get_id(n, 'start'), active_src, {
                n = tonumber(arc_vertical and n or 3),
                x = { 33, 64+32 }, 
                -- levels = { 4, 15 },
                levels = { 4, 15 },
                phase = sc.phase[n].rel,
                show_phase = sc.lvlmx[n].play == 1,
                sensitivity = 1/1000 * wparams.range,
                st = {
                    get_wparam(n, 'start'), 
                    function(v) set_wparam(n, 'start', v) end
                },
                len = { 
                    get_wparam(n, 'length'), 
                    function(v) set_wparam(n, 'length', v) end
                },
                recording = sc.punch_in[b].recording,
                recorded = sc.punch_in[b].recorded,
                reg = reg,
                voice = n,
                rotated = rotated,
            })
        end
        if arc_view[n][4] > 0 then
            _len(wparams:get_id(n, 'length'), active_src, {
                n = tonumber(arc_vertical and n or 4),
                x = { 33, 64+32 }, 
                phase = sc.phase[n].rel,
                show_phase = sc.lvlmx[n].play == 1,
                sensitivity = 1/1000 * wparams.range,
                -- level_st = alt and 15 or 4,
                -- level_en = alt and 4 or 15,
                -- level_ph = 4,
                -- level_st = props.levels[1],
                -- level_en = props.levels[2],
                -- level_ph = props.levels[1],
                levels = { 4, 15 },
                st = {
                    get_wparam(n, 'start'), 
                    function(v) set_wparam(n, 'start', v) end
                },
                len = { 
                    get_wparam(n, 'length'), 
                    function(v) set_wparam(n, 'length', v) end
                },
                recording = sc.punch_in[b].recording,
                recorded = sc.punch_in[b].recorded,
                reg = reg,
                voice = n,
                rotated = props.rotated,
            })
        end
    end
end

local function App(args)
    local rotated = args.rotated
    local wide = args.grid_wide

    local _voices = {}
    for i = 1,voices do
        _voices[i] = Voice()
    end

    return function()
        for n,_voice in ipairs(_voices) do
            _voice{ voice = n }
        end
    end
end

return App
