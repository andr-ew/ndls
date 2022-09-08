local function App(args)
    local rotated = args.rotated
    local wide = args.grid_wide
    local arc2 = args.arc2

    rotated = false --TODO: rotate mix & filter controls for arc2

    local function Cut(n, x)
        local _cut = Arc.control()
        local _filt = Components.arc.filter()

        return function()
            _cut{
                n = tonumber(vertical and n or x),
                x = { 42, 24+64 }, sens = 0.25, 
                redraw_enabled = false,
                state = of_mparam(n, 'cut'),
                controlspec = mparams:get_controlspec('cut', mparams_scope(n, 'cut')),
            }
            _filt{
                n = tonumber(vertical and n or x),
                x = { 42, 24+64 },
                type = mparams:get(n, 'type', mparams_scope(n, 'type')),
                cut = mparams:get(n, 'cut', mparams_scope(n, 'cut')),
            }
        end
    end

    local function Win(n, x)
        _st = Components.arc.st(mpat)

        return function() 
            local b = sc.buffer[n]

            _st{
                n = tonumber(vertical and n or x),
                x = { 33, 64+32 }, lvl = { 4, 15 },
                phase = sc.phase[n].rel,
                show_phase = sc.lvlmx[n].play == 1,
                sens = 1/1000,
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

    local function End(n, x)
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

    local function Vol(n, x)
        local _vol = Arc.number()

        return function() 
            _vol{
                n = x,
                sens = 0.25, max = 2.5, cycle = 1.5,
                state = of_mparam(n, 'vol'),
                lvl = view.track == n and 15 or 4,
            }
        end
    end

    local Pages = {}

    function Pages.mix(n)
        if arc2 then
            local _vol = Vol(n, 1)
            local _pan = Arc.control()

            return function()
                _vol()
                _pan{
                    n = 2,
                    state = of_mparam(n, 'pan'),
                    controlspec = mparams:get_controlspec(
                        'pan', mparams_scope(n, 'pan')
                    ),
                }
            end
        else
            local _vols = {}
            for n = 1,4 do
                _vols[n] = Vol(n, n)
            end

            return function() 
                for _,_vol in ipairs(_vols) do _vol() end
            end
        end
    end

    function Pages.window(n)
        if arc2 then
            local _win = Win(n, 1)
            local _end = End(n, 2)

            return function()
                _win(); _end()
            end
        else
            local _vol = Vol(n, 1)
            local _pan = Arc.control()
            local _win = Win(n, 3)
            local _end = End(n, 4)

            return function()
                _vol()
                _pan{
                    n = 2,
                    state = of_mparam(n, 'pan'),
                    controlspec = mparams:get_controlspec(
                        'pan', mparams_scope(n, 'pan')
                    ),
                }
                _win(); _end()
            end
        end
    end

    function Pages.filter(n)
        local _cut = Cut(n, 1)
        local _q = Arc.control()
        local _win = not arc2 and Win(n, 3)
        local _end = not arc2 and End(n, 4)

        return function()
            _cut()
            _q{
                n = 2,
                state = of_mparam(n, 'q'),
                controlspec = mparams:get_controlspec(
                    'q', mparams_scope(n, 'q')
                ),
                lvl = { 4, 4, 15 },
                x = { 42,  56 },
            }
            if not arc2 then
                _win(); _end()
            end
        end
    end

    local _pages = {}
    if arc2 then
        _pages.mix = {}
        for n = 1, voices do
            _pages.mix[n] = Pages.mix(n)
        end
    else
        --TODO: this version of component is fixed in the base scope
        --TODO: this component is also not mappable
        _pages.mix = Pages.mix()
    end
    _pages.window = {}
    _pages.filter = {}

    for n = 1, voices do
        _pages.window[n] = Pages.window(n)
        _pages.filter[n] = Pages.filter(n)
    end

    return function()
        if view.page == MIX then
            if arc2 then
                _pages.mix[view.track]()
            else
                _pages.mix()
            end
        elseif view.page == WINDOW then
            _pages.window[view.track]()
        elseif view.page == FILTER then
            _pages.filter[view.track]()
        elseif view.page == LFO then
        end

        if nest.arc.is_drawing() then
            freeze_patrol:ping('arc')
        end
    end
end

return App
