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
        { x = x[1], y = y[4] },
        { x = x[2], y = y[4] },
        { x = x[2], y = y[1] },
    }
    local k = {
        {  },
        { x = x[1], y = y[4] },
        { x = x[2], y = y[4] },
    }

    --local _alt = Key.momentary()

    --[[
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
    --]]
    
    local page_names = { 'v', 's', 'f', 'p' }
    local tab = 1
    local _tab = Text.enc.option()
    local _norns_view_tab = Text.enc.option()

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
        local function S(args)
            _st_view = Text.enc.number()
            _len_view = Text.enc.number()

            return function()
                if sc.punch_in[sc.buffer[args.voice]].recorded then
                    _st_view{
                        n = 2, x = e[2].x, y = e[2].y,
                        label = 'st', 
                        state = { get_start(args.voice, 'seconds') },
                        input_enabled = false,
                    }
                    _len_view{
                        n = 3, x = e[3].x, y = e[3].y,
                        label = 'len', 
                        state = { get_len(args.voice, 'seconds') },
                        input_enabled = false,
                    }

                    if nest.enc.has_input() then
                        local n, d = nest.enc.input_args()

                        local st = { get_start(args.voice), get_set_start(args.voice) }
                        local en = { get_end(args.voice), get_set_end(args.voice) }
                        
                        if n == 2 then
                            st[2](st[1] + d * args.sens)
                            en[2](en[1] + d * args.sens)

                            nest.screen.make_dirty()
                        elseif n == 3 then
                            en[2](en[1] + d * args.sens)

                            nest.screen.make_dirty()
                        end
                    end
                end
            end
        end
        _pages[2].s = S{ sens = 0.01, voice = n }
        --f
        do
            local _pg = _pages[3]
            _pg.cut = Ctl{ id = 'cut', voice = n, n = 2 }
            _pg.q = Ctl{ id = 'q', voice = n, n = 3 }
        end
        --p
        do
            local _pg = _pages[4]
            _pg.pan = Ctl{ id = 'pan', voice = n, n = 2 }
            _pg.bnd = Ctl{ id = 'bnd', voice = n, n = 3 }
        end

        return function(props)
            for _, _param in pairs(_pages[props.tab]) do _param() end
        end
    end
    
    local _voices = {}
    for i = 1, voices do
        _voices[i] = Voice{ n = i }
    end

    return function()
        -- _alt{
        --     n = 1, 
        --     state = {
        --         alt and 1 or 0,
        --         function(v)
        --             alt = v==1
        --             nest.arc.make_dirty()
        --         end
        --     }
        -- }

        _tab{
            x = e[1].x, y = e[1].y, n = 1,
            options = page_names, state = { tab, function(v) tab = v end }
        }
        _norns_view_tab{
            x = e[4].x, y = e[4].y, n = 4, options = { 1, 2, 3, 4 }, 
            state = { 
                norns_view, 
                function(v) 
                    norns_view = v 
                    nest.grid.make_dirty()
                end 
            }
        }

        _voices[norns_view]{ tab = tab//1 }
    end
end

return App
