local function App(args)
    local map = args.map
    local rotated = args.rotated
    local wide = args.grid_wide

    local Destinations = {}

    function Destinations.vol(n, x)
        local _num = to.pattern(mpat, 'vol '..n, Arc.number, function() 
            return {
                n = tonumber(vertical and n or x),
                sens = 0.25, max = 2.5, cycle = 1.5,
                state = of.param('vol '..n),
            }
        end)

        return function() _num() end
    end

    function Destinations.cut(n, x)
        local _cut = to.pattern(mpat, 'cut '..n, Arc.control, function() 
            return {
                n = tonumber(vertical and n or x),
                x = { 42, 24+64 }, sens = 0.25, 
                redraw_enabled = false,
                controlspec = of.controlspec('cut '..n),
                state = of.param('cut '..n),
            }
        end)

        local _filt = Components.arc.filter()

        local _type = to.pattern(mpat, 'type '..n, Arc.option, function() 
            return {
                n = tonumber(vertical and n or x),
                options = 4, sens = 1/64,
                x = { 27, 41 }, lvl = 12,
                --[[
                state = {
                    params:get('type '..n),
                    function(v) params:set('type '..n, v//1) end
                },
                --]]
                action = function(v) params:set('type '..n, v//1) end
            }
        end)

        return function() 
            _filt{
                n = tonumber(vertical and n or x),
                x = { 42, 24+64 },
                type = params:get('type '..n),
                cut = params:get('cut '..n),
            }

            if alt then 
                _type()
            else
                _cut() 
            end
        end
    end

    function Destinations.st(n, x)
        _st = Components.arc.st(mpat)

        return function() 
            local b = sc.buffer[n]

            _st{
                n = tonumber(vertical and n or x),
                x = { 33, 64+32 }, lvl = { 4, 15 },
                phase = sc.phase[n].rel,
                show_phase = sc.lvlmx[n].play == 1,
                sens = 1/1000,
                st = { get_start(n), get_set_start(n) },
                en = { get_end(n), get_set_end(n) },
                recording = sc.punch_in[b].recording,
                recorded = sc.punch_in[b].recorded,
                reg = reg.rec[b],
                rotated = rotated,
                --rec_flag = params:get('rec '..n)
            }
        end
    end

    function Destinations.len(n, x)
        _len = Components.arc.len(mpat)

        return function() 
            local b = sc.buffer[n]

            _len{
                n = tonumber(vertical and n or x),
                x = { 33, 64+32 }, 
                phase = sc.phase[n].rel,
                show_phase = sc.lvlmx[n].play == 1,
                nudge = alt,
                sens = 1/1000,
                lvl_st = alt and 15 or 4,
                lvl_en = alt and 4 or 15,
                lvl_ph = 4,
                st = { get_start(n), get_set_start(n) },
                en = { get_end(n), get_set_end(n) },
                recording = sc.punch_in[b].recording,
                recorded = sc.punch_in[b].recorded,
                reg = reg.rec[b],
                rotated = rotated,
                --rec_flag = params:get('rec '..n)
            }
        end
    end

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
                if view[y][x] > 0 then
                    _params[y][x]()
                end
            end end
        else
            local y = norns_view
            for x = 1,4 do
                _params[y][x]()
            end
        end
    end
end

return App