local Destinations = {}

function Destinations.vol(n, x)
    return function() 
        _arc.decimal{
            n = tonumber(arc_vertical and n or x),
            sensitivity = 0.25, max = 2.5, cycle = 1.5,
            state = of_mparam(n, 'vol'),
            levels = { 0, 15 },
        }
    end
end

function Destinations.cut(n, x)
    local _filt = Components.arc.filter()

    return function() 
        if crops.mode == 'redraw' then
            _arc.control{
                n = tonumber(arc_vertical and n or x),
                x = { 42, 24+64 }, sensitivity = 0.25, 
                state = of_mparam(n, 'cut'),
                controlspec = mparams:get_controlspec('cut'),
            }
        end
        _filt{
            n = tonumber(arc_vertical and n or x),
            x = { 42, 24+64 },
            type = mparams:get(n, 'type'),
            cut = mparams:get(n, 'cut'),
        }
    end
end

function Destinations.st(n, x)
    _st = Components.arc.st()

    return function() 
        local b = sc.buffer[n]

        _st{
            n = tonumber(arc_vertical and n or x),
            x = { 33, 64+32 }, 
            levels = { 4, 15 },
            phase = sc.phase[n].rel,
            show_phase = sc.lvlmx[n].play == 1,
            sensitivity = 1/1000,
            st = {
                wparams:get('start', n), 
                wparams:get_preset_setter('start', n)
            },
            en = { 
                wparams:get('end', n), 
                wparams:get_preset_setter('end', n)
            },
            recording = sc.punch_in[b].recording,
            recorded = sc.punch_in[b].recorded,
            reg = reg.rec[b],
            rotated = rotated,
        }
    end
end

function Destinations.len(n, x)
    _len = Components.arc.len()

    return function() 
        local b = sc.buffer[n]

        _len{
            n = tonumber(arc_vertical and n or x),
            x = { 33, 64+32 }, 
            phase = sc.phase[n].rel,
            show_phase = sc.lvlmx[n].play == 1,
            nudge = alt,
            sensitivity = 1/1000,
            level_st = alt and 15 or 4,
            level_en = alt and 4 or 15,
            level_ph = 4,
            st = {
                wparams:get('start', n), 
                wparams:get_preset_setter('start', n)
            },
            en = {
                wparams:get('end', n), 
                wparams:get_preset_setter('end', n)
            },
            recording = sc.punch_in[b].recording,
            recorded = sc.punch_in[b].recorded,
            reg = reg.rec[b],
            rotated = rotated,
        }
    end
end

local function App(args)
    local map = args.map
    local rotated = args.rotated
    local wide = args.grid_wide

    local _params = {}
    for y = 1,voices do --track
        _params[y] = {}

        for x = 1,4 do --map item

            _params[y][x] = Destinations[map[x]](y, x)
        end
    end

    return function()
        if wide then
            for y = 1,voices do for x = 1,4 do
                if arc_view[y][x] > 0 then
                    _params[y][x]()
                end
            end end
        else
            local y = view.track
            for x = 1,4 do
                _params[y][x]()
            end
        end
    end
end

return App
