local x,y = {}, {}

local mar = { left = 2, top = 4, right = 2, bottom = 0 }
local w = 128 - mar.left - mar.right
local h = 64 - mar.top - mar.bottom

x[1] = mar.left
x[1.5] = w * 5/16 + mar.left + 4
x[2] = w/2 + mar.left
x[2.5] = w * 13/16 + mar.left + 4
x[3] = 128 - mar.right
y[1] = mar.top + 4
y[2] = nil
y[3] = mar.top + h*(5.5/8) + 4
y[4] = mar.top + h*(7/8) + 4
y[5] = 64 - mar.bottom - 2 + 4

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

local function Ctl()
    return function(props)
        _enc.control{
            n = props.n, 
            level = { 4, 16 },
            state = of_mparam(props.voice, props.id),
            controlspec = mparams:get_controlspec(props.id),
        }
        _screen.list{
            x = e[props.n].x, y = e[props.n].y,
            text = { 
                [props.id] = util.round(mparams:get(props.voice, props.id), props.round or 0.01) 
            },
        }
    end
end

local function Rand(args)
    local blink_level = 1

    local rand = multipattern.wrap_set(
        mpat, args.id..'_'..args.voice..'_x', 
        function() 
            mparams:randomize(args.voice, args.id) 

            clock.run(function() 
                blink_level = 2
                crops.dirty.screen = true

                clock.sleep(0.2)

                blink_level = 1
                crops.dirty.screen = true
            end)
        end
    )

    return function(props)
        _key.momentary{
            n = props.n,
            input = function(z) if z>0 then rand() end end
        }
        _screen.text{
            text = 'x',
            y = k[props.n].y, x = k[props.n].x,
            level = ({ 4, 15 })[blink_level],
        }
    end
end

local function Window(args)
    local voice = args.voice

    local blink_level_st = 1
    local blink_level_en = 1

    local rand_wind = multipattern.wrap_set(
        mpat, 'window'..voice..'_x', function(target) 
            wparams:randomize(voice, target) 

            clock.run(function() 
                if target == 'both' or target == 'st' then blink_level_st = 2 end
                if target == 'both' or target == 'en' then blink_level_en = 2 end
                crops.dirty.screen = true

                clock.sleep(0.2)

                blink_level_st = 1
                blink_level_en = 1
                crops.dirty.screen = true
            end)
        end
    )

    local rand_wind_held = {}
    local function set_rand_wind_held(v)
        local old_st, old_en = rand_wind_held[1], rand_wind_held[2]
        local new_st, new_en = v[1], v[2]

        local both_last = old_st==1 and old_en==1
        local both_falling = both_last and (
            new_st==0 or new_en==0
        )
        local st_falling = new_st==0 and old_st==1
        local en_falling = new_en==0 and old_en==1

        if not both_last then
            if st_falling then rand_wind('st')
            elseif end_falling then rand_wind('en') end
        elseif both_falling then
            rand_wind('both')
        end

        rand_wind_held = v
    end

    return function(props)
        local sens = 0.01
        
        if sc.punch_in[sc.buffer[voice]].recorded then
            if crops.device == 'enc' and crops.mode == 'input' then
                local n, d = table.unpack(crops.args)

                local st = { 
                    wparams:get('start', voice), 
                    wparams:get_preset_setter('start', voice)
                }
                local en = { 
                    wparams:get('end', voice), 
                    wparams:get_preset_setter('end', voice)
                }
               
                if n == 2 then
                    st[2](st[1] + d * sens)
                    en[2](en[1] + d * sens)

                    crops.dirty.screen = true
                elseif n == 3 then
                    en[2](en[1] + d * sens)

                    crops.dirty.screen = true
                end
            end
            _screen.list{
                x = e[2].x, y = e[2].y,
                text = { 
                    win = util.round(wparams:get('start', voice, 'seconds'), 0.01)
                },
            }
            _screen.list{
                x = e[3].x, y = e[3].y,
                text = { 
                    len = util.round(wparams:get('length', voice, 'seconds'), 0.01)
                },
            }

            _key.momentaries{
                n = { 2, 3 },
                state = { 
                    rand_wind_held, 
                    set_rand_wind_held,
                }
            }
            _screen.text{
                text = 'x',
                y = k[2].y, x = k[2].x,
                level = ({ 4, 15 })[blink_level_st],
            }
            _screen.text{
                text = 'x',
                y = k[3].y, x = k[3].x,
                level = ({ 4, 15 })[blink_level_en],
            }
        end
    end
end

local function Voice(args)
    local n = args.n

    local _vol = Ctl()
    local _old = Ctl()
    local _rand_vol = Rand{ voice = n, id = 'vol' }
    local _rand_old = Rand{ voice = n, id = 'old' }

    local _window = Window{ voice = n }

    local _cut = Ctl()
    local _q = Ctl()
    local _rand_cut = Rand{ voice = n, id = 'cut' }

    local _pan = Ctl()
    local _rand_pan = Rand{ voice = n, id = 'pan' }
    local set_bnd = multipattern.wrap_set(mpat, 'bnd '..n, function(v)
        params:set('bnd '..n, v)
    end)

    return function(props)
        if props.tab == 1 then
            _vol{ id = 'vol', voice = n, n = 2 }
            _old{ id = 'old', voice = n, n = 3 }
            _rand_vol{ n = 2 }
            _rand_old{ n = 3 }
        elseif props.tab == 2 then
            _window()
        elseif props.tab == 3 then
            _cut{ id = 'cut', voice = n, n = 2 }
            _q{ id = 'q', voice = n, n = 3 }
            _rand_cut{ n = 2 }

            _key.integer{
                n_next = 3, min = 1,
                max = #mparams:get_options('type'),
                state = of_mparam(n, 'type'),
            }
            _screen.text{
                text = mparams:get_options('type')[mparams:get(n, 'type')],
                y = k[3].y, x = k[3].x, 
                level = 15,
            }
        elseif props.tab == 4 then
            _pan{ id = 'pan', voice = n, n = 2 }

            _enc.control{
                n = 3, 
                level = { 4, 16 },
                state = { params:get('bnd '..n), set_bnd },
                controlspec = params:lookup_param('bnd '..n).controlspec,
            }
            _screen.list{
                x = e[3].x, y = e[3].y,
                text = { 
                    bnd = util.round(params:get('bnd '), 0.01) 
                },
            }

            _rand_pan{ n = 2 }
        end
    end
end

local function App()
    -- local _alt = Key.momentary()

    local _waveform = Components.norns.waveform{ 
        x = { x[1], x[3] },
        y = { e[1].y + 8, e[2].y - 4 },
        --y = 64 / 2 + 1, amp = e[2].y - (64/2) - 2,
    }
    
    local remainder_view_page = 0
    local remainder_view_track = 0
    
    local track_names = {}
    for i = 1,voices do track_names[i] = i end
    
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
        --             nest.grid.make_dirty()
        --         end
        --     }
        -- }

        if crops.device == 'screen' and crops.mode == 'redraw' then
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

        _enc.integer{
            n = 1, max = #page_names,
            sens = 0.5,
            state = { 
                view.page, 
                function(v) 
                    view.page = v
                    crops.dirty.screen = true 
                    crops.dirty.grid = true 
                end 
            },
            state_remainder = { 
                remainder_view_page, 
                function(v) remainder_view_page = v end
            }
        }
        _screen.list{
            x = e[1].x, y = e[1].y, 
            text = page_names, focus = view.page,
        }

        _enc.integer{
            n = 4, max = #track_names,
            sens = 0.5,
            state = { 
                view.track, 
                function(v) 
                    view.track = v
                    crops.dirty.screen = true 
                    crops.dirty.grid = true 
                end 
            },
            state_remainder = { 
                remainder_view_page, 
                function(v) remainder_view_page = v end
            }
        }
        _screen.list{
            x = e[4].x, y = e[4].y, 
            text = track_names, focus = view.track,
        }

        _voices[view.track]{ tab = view.page//1 }
    end
end

return App
