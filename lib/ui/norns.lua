local x,y = {}, {}

local mar = { left = 14, top = 4, right = 14, bottom = 0 }
local w = 128 - mar.left - mar.right
local h = 64 - mar.top - mar.bottom
local xmar = 35

x[0] = 2
x[1] = mar.left
-- x[1.5] = w * 5/16 + mar.left + 6
x[1.5] = x[1] + xmar
-- x[2.5] = w * 13/16 + mar.left + 6
x[3] = 128 - mar.right
x[2.5] = x[3] - 3
x[2] = x[2.5] - xmar
y[1] = mar.top + 4
y[2] = y[1] + 4
y[4] = mar.top + h*(7/8) + 4 + 2
y[3] = y[4] - 17
y[3.5] = y[3] + 7
y[2.5] = 64 - mar.bottom - 2 + 4

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
local function Opt()
    local remainder = 0.0

    return function(props)
        local options = mparams:get_options(props.id)

        _enc.integer{
            n = props.n, 
            max = #options,
            state = of_mparam(props.voice, props.id),
            state_remainder = {
                remainder, function(v) remainder = v end
            }
        }
        _screen.list{
            x = e[props.n].x, y = e[props.n].y,
            text = { 
                [props.id] = options[mparams:get(props.voice, props.id)]
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
                if target == 'both' or target == 'len' then blink_level_en = 2 end
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
            elseif en_falling then rand_wind('len') end
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

    local _old = Ctl()
    local _vol = Ctl()
    local _pan = Ctl()
    local _rand_vol = Rand{ voice = n, id = 'vol' }
    local _rand_pan = Rand{ voice = n, id = 'pan' }

    local _window = Window{ voice = n }

    local _q = Ctl()
    local _cut = Ctl()
    local _typ = Opt()
    local _rand_cut = Rand{ voice = n, id = 'cut' }
    local _rand_typ = Rand{ voice = n, id = 'type' }

    local set_bnd = multipattern.wrap_set(mpat, 'bnd '..n, function(v)
        params:set('bnd '..n, v)
    end)

    return function(props)
        if props.tab == 1 then
            _old{ id = 'old', voice = n, n = 1 }
            _vol{ id = 'vol', voice = n, n = 2 }
            _pan{ id = 'pan', voice = n, n = 3 }
            _rand_vol{ n = 2 }
            _rand_pan{ n = 3 }
        elseif props.tab == 2 then
            _enc.control{
                n = 1, 
                level = { 4, 16 },
                state = { params:get('bnd '..n), set_bnd },
                controlspec = params:lookup_param('bnd '..n).controlspec,
            }
            _screen.list{
                x = e[1].x, y = e[1].y,
                text = { 
                    bnd = util.round(params:get('bnd '..n), 0.01) 
                },
            }
            _window()
        elseif props.tab == 3 then
            _q{ id = 'q', voice = n, n = 1 }
            _cut{ id = 'cut', voice = n, n = 2 }
            _typ{ id = 'type', voice = n, n = 3 }
            _rand_cut{ n = 2 }
            _rand_typ{ n = 2 }
        end
    end
end

local function App()
    local _waveform = Components.screen.waveform{ 
        x = { x[1] + 1, x[3] - 1 },
        y = { y[2], y[3] },
        --y = 64 / 2 + 1, amp = e[2].y - (64/2) - 2,
    }
    
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
            freeze_patrol:ping('screen')
        end

        do
            local n = view.track
            local b = sc.buffer[n]
            local recording = sc.punch_in[b].recording
            local recorded = sc.punch_in[b].recorded

            _waveform{
                reg = reg.rec[b], samples = sc.samples[b],
                --st = get_start(n), en = get_end(n), 
                st = wparams:get('start', n), en = wparams:get('end', n),
                phase = sc.phase[n].rel,
                recording = recording,
                recorded = recorded,
                show_phase = sc.lvlmx[n].play == 1,
                --rec_flag = params:get('rec '..n)
                render = function()
                    sc.samples:render(b)
                end
            }
            _screen.list{
                x = x[1], y = y[3.5], levels = { 2, 4 }, flow = 'right',
                focus = params:get('buffer '..n), margin = 2,
                text = tall and { 1, 2, 3, 4, 5, 6 } or { 1, 2, 3, 4 },
            }
            if recorded then
                _routines.screen.list_underline{
                    x = x[3], y = y[3.5], levels = { 2, 4 }, flow = 'left', margin = 2,
                    focus = (wide and 7 or 9) - (sc.phase[n].delta==0 and -1 or preset:get(n)) + 1, 
                    text = wide and { 
                        -- 'A', 'B', 'C', 'D', 'E', 'F', 'G' 
                        -- 'a', 'b', 'c', 'd', 'e', 'f', 'g',
                        -- 1, 2, 3, 4, 5, 6, 7
                        7, 6, 5, 4, 3, 2, 1
                    } or {
                        --TODO
                    },
                }
            end
        end

        _screen.list{
            x = e[4].x, y = e[1].y, 
            text = page_names, focus = view.page,
        }
        _routines.screen.list_highlight{
            x = x[0], y = y[2] + 6, flow = 'down', margin = 4, levels = { 4, 10 },
            text = track_names, focus = view.track, fixed_width = 4,
        }

        _voices[view.track]{ tab = view.page }
    end
end

return App
