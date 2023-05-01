local x,y = {}, {}

local mar = { left = 17, top = 4, right = 17, bottom = 0 }
local w = 128 - mar.left - mar.right
local h = 64 - mar.top - mar.bottom
local xmar = 40

x[0] = 2
x[1] = mar.left
-- x[1.5] = w * 5/16 + mar.left + 6
x[1.5] = x[1] + xmar
-- x[2.5] = w * 13/16 + mar.left + 6
x[3] = 128 - mar.right - 1
x[2.5] = x[3] - 3
x[2] = x[2.5] - xmar
y[1] = mar.top + 4
y[2] = y[1] + 4
y[4] = mar.top + h*(7/8) + 4 + 2 - 1
y[3] = y[4] - 17
y[3.5] = y[3] + 7
y[2.5] = 64 - mar.bottom - 2 + 4

local e = {
    { x = x[1], y = y[1] },
    { x = x[1], y = y[3.5] },
    { x = x[2], y = y[3.5] },
    { x = x[2], y = y[1] },
}
local k = {
    {  },
    { x = x[1.5], y = y[3.5] },
    { x = x[2.5], y = y[3.5] },
    { x = x[2.5], y = y[1] }
}

local function Mparam()
    local remainder_mparam = 0.0
    local remainer_scope = 0.0

    local nicknames = {
        global = 'glob',
        track = 'trk',
        preset = 'prst'
    }

    return function(props)
        local options = mparams:get_options(props.id)

        if alt then
            local scope_id = mparams.lookup[props.id].scope_id

            _enc.integer{
                n = props.n, 
                max = #params:lookup_param(scope_id).options,
                state = {
                    params:get(scope_id),
                    params.set, params, scope_id,
                },
                state_remainder = { remainder_scope, function(v) remainder_scope = v end }
            }
        elseif options then
            _enc.integer{
                n = props.n, 
                max = #options,
                state = of_mparam(props.voice, props.id),
                state_remainder = { remainder_mparam, function(v) remainder_mparam = v end }
            }
        else
            _enc.control{
                n = props.n, 
                state = of_mparam(props.voice, props.id),
                controlspec = mparams:get_controlspec(props.id),
            }
        end

        local scope = mparams:get_scope(props.id); --wild -- the semicolin is needed here !
        (
            scope=='global' and _screen.list 
            or scope=='track' and _routines.screen.list_highlight
            or scope=='preset' and _routines.screen.list_underline
        ){
            x = e[props.n].x, y = e[props.n].y, margin = 4, nudge = props.n==1,
            text = { 
                [props.id] = alt and (
                    nicknames[scope]
                ) or options and (
                    options[mparams:get(props.voice, props.id)]
                ) or (
                    string.format('%.2f', mparams:get(props.voice, props.id))
                )
            },
        }
    end
end

local function Rand(args)
    local blink_level = 1
    local holdblink = false
    local downtime = nil

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
    local def = multipattern.wrap_set(
        mpat, args.id..'_'..args.voice..'_d', 
        function() 
            holdblink = true
            blink_level = 1
            crops.dirty.screen = true

            clock.run(function() 
                clock.sleep(0.1)
                blink_level = 2
                crops.dirty.screen = true

                mparams:defaultize(args.voice, args.id) 

                clock.sleep(0.2)
                blink_level = 1
                crops.dirty.screen = true

                clock.sleep(0.4)
                holdblink = false
                crops.dirty.screen = true
            end)
        end
    )
    
    local nicknames = {
        default = 'd',
        random = 'x',
    }

    return function(props)
        if alt then
            if mparams:get_scope(args.id) == 'preset' then
                local reset_id = args.id..'_reset'

                _key.integer{
                    n_next = props.n, max = #params:lookup_param(reset_id).options,
                    state = {
                        params:get(reset_id),
                        params.set, params, reset_id,
                    },
                }
                _screen.text{
                    x = k[props.n].x, y = k[props.n].y,
                    text = nicknames[params:string(reset_id)],
                    level = 15,
                }
            end
        else
            if crops.device == 'key' and crops.mode == 'input' then
                local n, z = table.unpack(crops.args) 

                if n == props.n then
                    if z==1 then
                        downtime = util.time()
                    elseif z==0 then
                        if downtime and ((util.time() - downtime) > 0.5) then def()
                        else rand() end
                        
                        downtime = nil
                    end
                end
            end

            _screen.text{
                x = k[props.n].x, y = k[props.n].y,
                text = holdblink and 'd' or 'x',
                level = ({ 4, 15 })[blink_level],
            }
        end
    end
end

local function Window(args)
    local voice = args.voice

    local blink_level_st = 1
    local blink_level_en = 1
    local holdblink_st = false
    local holdblink_en = false
    local downtime = nil

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
    local def_wind = multipattern.wrap_set(
        mpat, 'window'..voice..'_d', function(target) 
            if target == 'both' or target == 'st' then holdblink_st = true end
            if target == 'both' or target == 'len' then holdblink_en = true end
            blink_level_st = 1
            blink_level_en = 1
            crops.dirty.screen = true

            clock.run(function() 
                clock.sleep(0.1)
                if target == 'both' or target == 'st' then blink_level_st = 2 end
                if target == 'both' or target == 'len' then blink_level_en = 2 end
                crops.dirty.screen = true

                wparams:defaultize(voice, target) 

                clock.sleep(0.2)
                blink_level_st = 1
                blink_level_en = 1
                crops.dirty.screen = true

                clock.sleep(0.4)
                holdblink_st = false
                holdblink_en = false
                crops.dirty.screen = true
            end)
        end
    )


    local rand_wind_held = {}
    local function set_rand_wind_held(v)
        local old_st, old_en = rand_wind_held[1] or 0, rand_wind_held[2] or 0
        local new_st, new_en = v[1], v[2]

        local both_last_low = old_st==0 and old_en==0
        local both_last_high = old_st==1 and old_en==1

        local any_rising = both_last_low and (
            new_st==1 or new_en==1
        )
        local both_falling = both_last_high and (
            new_st==0 or new_en==0
        )
        local st_falling = new_st==0 and old_st==1
        local en_falling = new_en==0 and old_en==1

        if any_rising then
            downtime = util.time()
        elseif not both_last_high then
            if st_falling then 
                if downtime and ((util.time() - downtime) > 0.5) then def_wind('st')
                else rand_wind('st') end
                downtime = nil
            elseif en_falling then 
                if downtime and ((util.time() - downtime) > 0.5) then def_wind('len')
                else rand_wind('len') end
                downtime = nil
            end
        elseif both_falling then
            if downtime and ((util.time() - downtime) > 0.5) then def_wind('both')
            else rand_wind('both') end
            
            downtime = nil
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

            --TODO: adjust list style based on scope
            _routines.screen.list_underline{
                x = e[2].x, y = e[2].y,
                text = { 
                    win = util.round(wparams:get('start', voice, 'seconds'), 0.01)
                },
            }
            _routines.screen.list_underline{
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
                text =  holdblink_st and 'd' or 'x',
                y = k[2].y, x = k[2].x,
                level = ({ 4, 15 })[blink_level_st],
            }
            _screen.text{
                text =  holdblink_en and 'd' or 'x',
                y = k[3].y, x = k[3].x,
                level = ({ 4, 15 })[blink_level_en],
            }
        end
    end
end

local function Voice(args)
    local n = args.n

    local _old = Mparam()
    local _lvl = Mparam()
    local _spr = Mparam()
    local _rand_lvl = Rand{ voice = n, id = 'lvl' }
    local _rand_spr = Rand{ voice = n, id = 'spr' }

    local _window = Window{ voice = n }
    local _loop = Mparam()

    local _q = Mparam()
    local _cut = Mparam()
    local _typ = Mparam()
    local _rand_cut = Rand{ voice = n, id = 'cut' }
    local _rand_typ = Rand{ voice = n, id = 'type' }

    local set_bnd = multipattern.wrap_set(mpat, 'bnd '..n, function(v)
        params:set('bnd '..n, v)
    end)

    return function(props)
        if props.tab == 1 then
            _old{ id = 'old', voice = n, n = 1 }
            _lvl{ id = 'lvl', voice = n, n = 2 }
            _spr{ id = 'spr', voice = n, n = 3 }
            _rand_lvl{ n = 2 }
            _rand_spr{ n = 3 }
        elseif props.tab == 2 then
            if alt then
                _loop{ id = 'loop', voice = n, n = 3 }
            else
                _enc.control{
                    n = 1, 
                    level = { 4, 16 },
                    state = { params:get('bnd '..n), set_bnd },
                    controlspec = params:lookup_param('bnd '..n).controlspec,
                }
                --TODO: adjust list style based on scope
                _routines.screen.list_highlight{
                    x = e[1].x, y = e[1].y, nudge = true,
                    text = { 
                        rate = util.round(params:get('bnd '..n), 0.01) 
                    },
                }
                _window()
            end
        elseif props.tab == 3 then
            _q{ id = 'q', voice = n, n = 1 }
            _cut{ id = 'cut', voice = n, n = 2 }
            _typ{ id = 'type', voice = n, n = 3 }
            _rand_cut{ n = 2 }
            _rand_typ{ n = 3 }
        end
    end
end

local function App()
    local _waveform, _filtergraph
    do
        local left, right = x[1] + 1, x[3] - 1
        local top, bottom = y[2], y[3]

        _waveform = Components.screen.waveform{ 
            x = { left, right },
            y = { top, bottom },
            --y = 64 / 2 + 1, amp = e[2].y - (64/2) - 2,
        }
        _filtergraph = Components.screen.filtergraph{
            x = left, w = right - left, 
            y = top, h = bottom - top,
        }
    end
    
    local track_names = {}
    for i = 1,voices do track_names[i] = i end

    local _recglyph = Components.screen.recglyph()
    
    local _voices = {}
    for i = 1, voices do
        _voices[i] = Voice{ n = i }
    end

    return function()
        _key.momentary{
            n = 1,
            state = {
                alt and 1 or 0,
                function(v)
                    alt = v==1
                    crops.dirty.screen = true
                    crops.dirty.grid = true
                end
            }
        }

        if crops.device == 'screen' and crops.mode == 'redraw' then
            freeze_patrol:ping('screen')
        end

        do
            local n = view.track
            local b = sc.buffer[n]
            local recording = sc.punch_in[b].recording
            local recorded = sc.punch_in[b].recorded
            local tab = view.page

            if tab == 1 then
                local levels_focus = { 4, 15 }
                local levels = { 2, 8 }
                local level_mark_focus = 4
                local level_mark = 2

                for i = 1,4 do
                    do
                        local y = y[2] + 3 + ((i-1) * (5 + 4 - 1))

                        do
                            local x = e[2].x
                            local l = k[2].x - e[2].x
                            local spec = mparams:get_controlspec('lvl')

                            _routines.screen.meter{
                                x = x, y = y, length = l, width = 3,
                                levels = i==view.track and { 0, 12 } or { 0, 4 },
                                outline = true,
                                level_mark = i==view.track and level_mark_focus or level_mark,
                                amount = spec:unmap(sc.lvlmx[i].db),
                                mark = spec:unmap(0)
                            }
                        end
                        do
                            local x = k[2].x
                            local l = e[3].x - k[2].x - 3
                            local spec = mparams:get_controlspec('old')

                            _routines.screen.meter{
                                x = x, y = y, length = l, width = 1,
                                levels = i==view.track and levels_focus or levels,
                                amount = util.linlin(
                                    spec.minval, spec.maxval, 0, 1, mparams:get(i, 'old')
                                )
                            }
                        end
                        do
                            local l = k[3].x - e[3].x
                            local x = x[3] - l

                            _routines.screen.dial{
                                x = x, y = y, length = l, width = 1,
                                levels = i==view.track and levels_focus or levels,
                                amount = util.linlin(
                                    -1, 1, 0, 1, sc.sprmx[i].pan
                                ),
                                mark = util.linlin(
                                    -1, 1, 0, 1, 0
                                )
                            }
                        end
                    end
                end
            elseif tab == 2 then
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
            elseif tab == 3 then
                _filtergraph{
                    filter_type = ({ 
                        'lowpass', 'bandpass', 'highpass', 'bypass' 
                    })[
                        mparams:get(n, 'type')
                    ],
                    freq = util.linexp(0, 1, 20, 20000, mparams:get(n, 'cut')),
                    -- resonance = util.linexp(0, 1, 0.01, 20, mparams:get(n, 'q')),
                    resonance = mparams:get(n, 'q'),
                }
            end

            _screen.list{
                x = x[1], y = y[4], levels = { 2, 4 }, flow = 'right',
                focus = params:get('buffer '..n), margin = 2,
                text = tall and { 1, 2, 3, 4, 5, 6 } or { 1, 2, 3, 4 },
            }
            if recorded then
                _routines.screen.list_underline{
                    x = x[3], y = y[4], levels = { 2, 4 }, flow = 'left', margin = 2,
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

        _screen.glyph{
            x = x[3] - 1, y = e[4].y, align = 'right',
            glyph = [[
                . # . . # . . . . @ @ . . . @ @ . . . % % % % . .
                # # # . # . . . @ . . @ . @ . . @ . . . . . . % .
                . # . . # . . . @ . . @ . @ . . @ . . . . . . % .
                . # . # # # . . . @ @ . . . @ @ . . . . . . . . %
                . # . . # . . . . . @ @ @ @ @ . . . . . . . . . %
            ]],
            levels = { 
                ['.'] = 0, 
                ['#'] = view.page==1 and 10 or 4, 
                ['@'] = view.page==2 and 10 or 4,
                ['%'] = view.page==3 and 10 or 4,
            }
        }
        _routines.screen.list_highlight{
            x = x[0], y = y[2] + 5, flow = 'down', margin = 3, levels = { 4, 10 },
            text = track_names, focus = view.track, fixed_width = 4, nudge = true,
        }

        do
            local y = y[2]
            for i = 1,tracks do
                _screen.glyph{
                    x = 128 - 12, y = y,
                    glyph = [[
                        . # # # # . . @ . . . .
                        . . . # # . . . @ . . @
                        . . # . # . . . . @ . @
                        . # . . # . . . . . @ @
                        # . . . . . . . @ @ @ @
                    ]],
                    levels = {
                        ['.'] = 0, 
                        ['#'] = params:get('send '..i)>0 and 6 or 2, 
                        ['@'] = params:get('return '..i)>0 and 6 or 2,
                    }
                }

                y = y + 8
            end
        end

        do
            local n = view.track
            local b = sc.buffer[n]
            local recording = sc.punch_in[b].recording
            local recorded = sc.punch_in[b].recorded
            local play = sc.lvlmx[n].play

            if not tall then
                _recglyph{
                    x = x[0], y = y[4] - 4,
                    rec = sc.oldmx[n].rec, play = play,
                    recorded = recorded,
                    recording = recording,
                    levels = { 2, 6 },
                }
            end
            if recorded then
                _screen.glyph{
                    x = x[0] + 5 + 3, y = y[4] - 4,
                    levels = { ['.'] = 0, ['#'] = 6 },
                    glyph = play>0 and [[
                        # . . #
                        # . . #
                        # . . #
                        # . . #
                        # . . #
                    ]] or [[
                        # . .
                        # # .
                        # # #
                        # # .
                        # . .
                    ]]
                }

                local loop = sc.loopmx[n].loop
                _screen.glyph{
                    x = 128 - 12, y = e[4].y - 5,
                    levels = { ['.'] = 0, ['#'] = 4 },
                    glyph = loop>0 and [[
                        . # # # # # # # # # # .
                        # . . . . . . . . . . #
                        # . . # . . . . . . . #
                        . # # # # . . # # # # .
                        . . . # . . . . . . . .
                    ]] or [[
                        . . . . . . . . # . . #
                        . . . . . . . . . # . #
                        # # # # # # # # # # # #
                        . . . . . . . . . # . #
                        . . . . . . . . # . . #
                    ]]
                }
            end
        end

        _voices[view.track]{ tab = view.page }
    end
end

return App
