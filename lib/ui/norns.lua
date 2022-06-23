local function App()
    local x,y = {}, {}

    local mar = { left = 2, top = 4, right = 2, bottom = 0 }
    local w = 128 - mar.left - mar.right
    local h = 64 - mar.top - mar.bottom

    x[1] = mar.left
    x[2] = 128/2
    y[1] = mar.top
    y[2] = nil
    y[3] = mar.top + h*(5.5/8)
    y[4] = mar.top + h*(7/8)

    local e = {
        { x = x[1], y = y[1] },
        { x = x[1], y = y[3] },
        { x = x[2], y = y[3] },
    }
    local k = {
        {  },
        { x = x[1], y = y[4] },
        { x = x[2], y = y[4] },
    }

    local _alt = Key.momentary()

    local _crossfader
    do
        local x, y, width, height = x[1], y[1], 128 - mar.left - mar.right, 3
        local value = params:get('crossfade')
        local min_value = params:lookup_param('crossfade').controlspec.minval
        local max_value = params:lookup_param('crossfade').controlspec.maxval
        local markers = { 0 }
        local direction = 'right'
        _crossfader = Components.norns.slider(
            x, y, width, height, value, min_value, max_value, markers, direction
        )
    end
    
    local page_names = { 'v', 's', 'f', 'p' }
    local tab = 1
    local _tab = Text.enc.option()

    local function Ctl(args)
        local _ctl = to.pattern(mpat, args.id..' '..args.voice, Text.enc.control, function()
            return {
                n = args.n, x = e[args.n].x, y = e[args.n].y,
                label = args.id, 
                state = of.param(args.id..' '..args.voice),
                controlspec = of.controlspec(args.id..' '..args.voice),
            }
        end)

        return _ctl
    end

    local function Voice(args)
        local n = args.n

        local _pages = {}
        for i = 1, #page_names do _pages[i] = {} end

        --v
        do
            local _pg = _pages[1]
            _pg.cut = Ctl{ id = 'vol', voice = n, n = 2 }
            _pg.old = Ctl{ id = 'old', voice = n, n = 3 }
        end
        --s
        do
        end
        --f
        do
            local _pg = _pages[3]
            _pg.cut = Ctl{ id = 'cut', voice = n, n = 2 }
            _pg.q = Ctl{ id = 'q', voice = n, n = 3 }
        end
        --p
        do
            local _pg = _pages[4]
            _pg.bnd = Ctl{ id = 'bnd', voice = n, n = 2 }
            _pg.pan = Ctl{ id = 'pan', voice = n, n = 3 }
        end

        return function(props)
            for _, _param in pairs(_pages[props.tab]) do _param() end
        end
    end
    
    local _voices = {}
    for i = 1, ndls.voices do
        _voices[i] = Voice{ n = i }
    end

    return function()
        _alt{
            n = 1, 
            state = {
                alt and 1 or 0,
                function(v)
                    alt = v==1
                    nest.arc.make_dirty()
                end
            }
        }
        local focus = track_focus()

        if focus then
            _tab{
                x = x[1], y = y[1], n = 1,
                options = page_names, state = { tab, function(v) tab = v end }
            }

            _voices[focus]{ tab = tab//1 }
        else
            _crossfader{
                n = 1,
                state = of.param('crossfade')
            }
        end
    end
end

return App
