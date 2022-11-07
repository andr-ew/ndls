local function App()
    local x,y = {}, {}

    local mar = { left = 2, top = 4, right = 2, bottom = 0 }
    local w = 128 - mar.left - mar.right
    local h = 64 - mar.top - mar.bottom

    x[1] = mar.left
    x[1.5] = w * 5/16 + mar.left + 4
    x[2] = w/2 + mar.left
    x[2.5] = w * 13/16 + mar.left + 4
    x[3] = 128 - mar.right
    y[1] = mar.top
    y[2] = nil
    y[3] = mar.top + h*(5.5/8)
    y[4] = mar.top + h*(7/8)
    y[5] = 64 - mar.bottom - 2

    local e = {
        { x = x[1], y = y[1] },
        { x = x[1], y = y[4] },
        { x = x[2], y = y[4] },
        { x = x[2], y = y[1] },
    }
    local k = {
        {  },
        { x = x[1.5], y = y[4] },
        { x = x[2.5], y = y[4] },
        { x = x[2.5], y = y[1] }
    }

    local _alt = Key.momentary()

    local _tab = Text.enc.option()
    local _norns_view_tab = Text.enc.option()

    local function Ctl()
        local _ctl = Text.enc.control()

        return function(props)
            _ctl{
                n = props.n, x = e[props.n].x, y = e[props.n].y,
                --label = (scope == 'base_sum') and string.upper(props.id) or props.id, 
                label = props.id,
                lvl = { 4, 16 },
                state = of_mparam(props.voice, props.id),
                controlspec = mparams:get_controlspec(props.id),
            }
        end
    end
    local function Rand(args)
        local _rand = Text.key.trigger()
        local rand = multipattern.wrap_set(
            mpat, args.id..'_'..args.voice..'_x', 
            function() mparams:randomize(args.voice, args.id) end
        )

        return function(props)
            _rand{
                label = 'x', n = props.n,
                y = k[props.n].y, x = k[props.n].x,
                action = rand,
            }
        end
    end
    local function Window(args)
        local voice = args.voice

        local _st_view = Text.enc.number()
        local _win_view = Text.enc.number()
        local _len_view = Text.enc.number()
        
        local _rand_wind = Text.key.trigger()
        local rand_wind = multipattern.wrap_set(
            mpat, 'window'..args.voice..'_x', function(target) wparams:randomize(voice, target) end
        )

        return function(props)
            local sens = 0.01
            
            if sc.punch_in[sc.buffer[voice]].recorded then
                _st_view{
                    n = 1, x = e[1].x, y = e[1].y,
                    label = 'st', 
                    state = { wparams:get('start', voice, 'seconds') },
                    input_enabled = false,
                }
                _win_view{
                    n = 2, x = e[2].x, y = e[2].y,
                    label = 'win', 
                    state = { wparams:get('start', voice, 'seconds') },
                    input_enabled = false,
                }
                _len_view{
                    n = 3, x = e[3].x, y = e[3].y,
                    label = 'len', 
                    state = { wparams:get('length', voice, 'seconds') },
                    input_enabled = false,
                }

                if nest.enc.has_input() then
                    local n, d = nest.enc.input_args()

                    local st = { 
                        wparams:get('start', voice), 
                        wparams:get_preset_setter('start', voice)
                    }
                    local en = { 
                        wparams:get('end', voice), 
                        wparams:get_preset_setter('end', voice)
                    }
                   
                    if n == 1 then
                        st[2](st[1] + d * sens)

                        nest.screen.make_dirty()
                    elseif n == 2 then
                        st[2](st[1] + d * sens)
                        en[2](en[1] + d * sens)

                        nest.screen.make_dirty()
                    elseif n == 3 then
                        en[2](en[1] + d * sens)

                        nest.screen.make_dirty()
                    end
                end

                _rand_wind{
                    label = { 'x', 'x' },
                    edge = 'falling',
                    n = { 2, 3 },
                    y = k[2].y, x = { { k[2].x }, { k[3].x } },
                    action = function(v, t, d, add, rem, l)
                        if #l == 2 then rand_wind('both')
                        else rand_wind(add==2 and 'len' or 'st') end
                    end
                }
            end
        end
    end

    local function Voice(args)
        local n = args.n

        local _old = Ctl()
        local _vol = Ctl()
        local _pan = Ctl()
        local _rand_vol = Rand{ voice = n, id = 'vol' }
        local _rand_pan = Rand{ voice = n, id = 'pan' }

        local _window = Window{ voice = n }

        local _q = Ctl()
        local _cut = Ctl()
        local _typ = Text.enc.number()
        local _rand_cut = Rand{ voice = n, id = 'cut' }
        local _rand_type = Rand{ voice = n, id = 'type' }

        return function(props)
            if props.tab == MIX then
                _old{ id = 'old', voice = n, n = 1 }
                _vol{ id = 'vol', voice = n, n = 2 }
                _pan{ id = 'pan', voice = n, n = 3 }
                _rand_vol{ n = 2 }
                _rand_pan{ n = 3 }
            elseif props.tab == WINDOW then
                _window()
            elseif props.tab == FILTER then
                _q{ id = 'q', voice = n, n = 1 }
                _cut{ id = 'cut', voice = n, n = 2 }
                do
                    local options = mparams:get_options('type')
                    _typ{
                        label = 'type', 
                        lvl = { 4, 16 },
                        n = 3, y = e[3].y, x = e[3].x, 
                        min = 1, step = 1, inc = 1, max = #options,
                        formatter = function(v) return options[v] end,
                        state = of_mparam(n, 'type'),
                    }
                end
                _rand_cut{ n = 2 }
                _rand_type{ n = 3 }
            elseif props.tab == LFO then
            end
        end
    end
    
    local _voices = {}
    for i = 1, voices do
        _voices[i] = Voice{ n = i }
    end

    local _waveform = Components.norns.waveform{ 
        x = { x[1], x[3] },
        y = { e[1].y + 8, e[2].y - 4 },
        --y = 64 / 2 + 1, amp = e[2].y - (64/2) - 2,
    }

    local norns_view_pages = {}
    for i = 1,voices do norns_view_pages[i] = i end

    local _page_label = Text.label()
    local _track_label = Text.label()

    return function()
        _alt{
            n = 1, 
            state = {
                alt and 1 or 0,
                function(v)
                    alt = v==1
                    nest.arc.make_dirty()
                    nest.grid.make_dirty()
                end
            }
        }

        if nest.screen.is_drawing() then
            --draw view display
            for p = 1, 4 do
                for t = 1, voices do
                    local x = (p-1)*2 + x[3] - (3*2)
                    local y = (t-1)*2 + y[1] - 2
                    local hl = (p == view.page) and (t == view.track)
                    screen.level(hl and 15 or 4)
                    screen.pixel(x, y)
                    screen.fill()
                end
            end
            --draw preset display
            do
                local n = view.track
                local b = sc.buffer[n]
                local sl = sc.slice[n][b]

                if sc.punch_in[b].recorded then
                    if wide then
                        for i = 1, slices do
                            local x = i + x[3] - slices
                            local y = y[5] - 2
                            local hl = i == sl
                            local frst = i == 1
                            screen.level(hl and 15 or frst and 8 or 4)
                            screen.pixel(x, y)
                            screen.fill()
                        end
                    else
                        for ix = 1, 3 do
                            for iy = 1,3 do
                                local x = (ix-1)*2 + x[3] - (2*2)
                                local y = (iy-1)*2 + y[5] - (3*2)
                                local sx = (sl-1) % 3 + 1
                                local sy = (sl - 1) // 3 + 1
                                local hl = (ix == sx) and (iy == sy)
                                local frst = (ix == 1) and (iy == 1)
                                screen.level(hl and 15 or frst and 8 or 4)
                                screen.pixel(x, y)
                                screen.fill()
                            end
                        end
                    end
                end
            end

            freeze_patrol:ping('screen')
        end

        _page_label{
            x = e[4].x, y = e[4].y, label = page_names[view.page], lvl = 4,
        }
        _track_label{
            x = k[4].x, y = k[4].y, label = view.track, lvl = 8,
        }
        
        do
            local n = view.track
            local b = sc.buffer[n]
            _waveform{
                reg = reg.rec[b], samples = sc.samples[b],
                --st = get_start(n), en = get_end(n), 
                st = wparams:get('start', n), en = wparams:get('end', n),
                phase = sc.phase[n].rel,
                recording = sc.punch_in[b].recording,
                recorded = sc.punch_in[b].recorded,
                show_phase = sc.lvlmx[n].play == 1,
                --rec_flag = params:get('rec '..n)
                render = function()
                    sc.samples:render(b)
                end
            }
        end

        _voices[view.track]{ tab = view.page//1 }
    end
end

return App
