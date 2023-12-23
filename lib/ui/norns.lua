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

local function secs_to_mins_secs(secs) 
    local mins, secs_div_60 = math.modf(secs/60)
    return string.format('%d:%.2d', mins, util.round(secs_div_60 * 60))
end
local function format_time(secs)
    return (secs > 60) and secs_to_mins_secs(secs) or util.round(secs, 0.01)
end

local function Mparam()
    local nicknames = {
        global = 'glob',
        track = 'trk',
        preset = 'prst'
    }

    local _scope = Enc.integer()
    local _option = Enc.integer()
    local _control = Enc.control()

    local _list_global = Screen.list()
    local _list_track = Components.screen.list_highlight()
    local _list_preset = Components.screen.list_underline()

    return function(props)
        local options = mparams:get_options(props.id)

        if alt then
            local scope_id = mparams.lookup[props.id].scope_id

            _scope{
                n = props.n, 
                max = #params:lookup_param(scope_id).options,
                state = {
                    params:get(scope_id),
                    params.set, params, scope_id,
                },
                state_remainder = { remainder_scope, function(v) remainder_scope = v end }
            }
        elseif options then
            _option{
                n = props.n, 
                max = #options,
                state = of_mparam(props.voice, props.id),
                state_remainder = { remainder_mparam, function(v) remainder_mparam = v end }
            }
        else
            _control{
                n = props.n, 
                state = of_mparam(props.voice, props.id),
                controlspec = mparams:get_controlspec(props.id),
            }
        end

        local scope = mparams:get_scope(props.id); --wild -- the semicolin is needed here !
        (
            scope=='global' and _list_global
            or scope=='track' and _list_track
            or scope=='preset' and _list_preset
        ){
            x = e[props.n].x, y = e[props.n].y, margin = 4, nudge = props.n==1,
            levels = props.levels,
            text = { 
                [props.name or props.id] = alt and (
                    nicknames[scope]
                ) or options and (
                    options[get_mparam(props.voice, props.id)]
                ) or (
                    string.format('%.2f', get_mparam(props.voice, props.id))
                )
            },
        }
    end
end

local function Rand(args)
    local blink_level = 1
    local holdblink = false
    local downtime = nil

    local rand_id = 'randomize '..args.id..' '..args.voice
    local def_id = 'defaultize '..args.id..' '..args.voice

    params:set_action(rand_id, function() 
        mparams:randomize(args.voice, args.id) 

        clock.run(function() 
            blink_level = 2
            crops.dirty.screen = true

            clock.sleep(0.2)

            blink_level = 1
            crops.dirty.screen = true
        end)
    end)
    params:set_action(def_id, function() 
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
    end)

    local nicknames = {
        default = 'd',
        random = 'x',
    }

    local _reset_action = {
        key = Key.integer(),
        screen = Screen.text(),
    }

    local _action = Screen.text()

    return function(props)
        if alt then
            if mparams:get_scope(args.id) == 'preset' then
                local reset_id = args.id..'_reset'
                _reset_action.key{
                    n_next = props.n, max = #params:lookup_param(reset_id).options,
                    state = {
                        params:get(reset_id),
                        params.set, params, reset_id,
                    },
                }
                _reset_action.screen{
                    x = k[props.n].x, y = k[props.n].y,
                    text = nicknames[params:string(reset_id)],
                    level = 15,
                }
            end
        else
            if crops.device == 'key' and crops.mode == 'input' then
                local n, z = table.unpack(crops.args) 
                local retrigger = true

                if n == props.n then
                    if z==1 then
                        downtime = util.time()
                    elseif z==0 then
                        if downtime and ((util.time() - downtime) > 0.5) then 
                            set_param(def_id, 0, retrigger)
                        else 
                            set_param(rand_id, 0, retrigger)
                        end
                        
                        downtime = nil
                    end
                end
            end

            _action{
                x = k[props.n].x, y = k[props.n].y,
                text = holdblink and 'd' or 'x',
                level = ({ 4, 15 })[blink_level],
            }
        end
    end
end

local function Rands_window(args)
    local voice = args.voice
    local i = voice

    local blink_level_st = 1
    local blink_level_en = 1
    local holdblink_st = false
    local holdblink_en = false
    local downtime = nil

    for _,target in ipairs{ 'st', 'len', 'both' } do
        params:set_action('randomize '..target..' '..i, function() 
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
        end)
        params:set_action('defaultize '..target..' '..i, function() 
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
        end)
    end

    local rand_wind_held = {}
    local function set_rand_wind_held(v)
        local retrigger = true

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
                if downtime and ((util.time() - downtime) > 0.5) then 
                    set_param('defaultize '..'st'..' '..i, 0, retrigger)
                else 
                    set_param('randomize '..'st'..' '..i, 0, retrigger)
                end
                downtime = nil
            elseif en_falling then 
                if downtime and ((util.time() - downtime) > 0.5) then 
                    set_param('defaultize '..'len'..' '..i, 0, retrigger)
                else 
                    set_param('randomize '..'len'..' '..i, 0, retrigger)
                end
                downtime = nil
            end
        elseif both_falling then
            if downtime and ((util.time() - downtime) > 0.5) then 
                set_param('defaultize '..'both'..' '..i, 0, retrigger)
            else 
                set_param('randomize '..'both'..' '..i, 0, retrigger)
            end
            
            downtime = nil
        end

        rand_wind_held = v
    end

    --TODO: adjust list style based on scope
    local _st = Components.screen.list_underline()
    local _len = Components.screen.list_underline()

    local _actions = Key.momentaries()
    local _action = {
        st = { screen = Screen.text() },
        len = { screen = Screen.text() },
    }

    return function(props)
        if sc.punch_in[sc.buffer[voice]].recorded then
            _actions{
                n = props.n,
                state = { 
                    rand_wind_held, 
                    set_rand_wind_held,
                }
            }
            _action.st.screen{
                text =  holdblink_st and 'd' or 'x',
                y = k[props.n[1]].y, x = k[props.n[1]].x,
                level = props.levels[blink_level_st],
            }
            _action.len.screen{
                text =  holdblink_en and 'd' or 'x',
                y = k[props.n[2]].y, x = k[props.n[2]].x,
                level = props.levels[blink_level_en],
            }
        end
    end
end

local function Start()
    --TODO: adjust list style based on scope
    local _st = Components.screen.list_underline()

    return function(props)
        local sens = props.sensitivity or 0.01
        local voice = props.voice
        
        if sc.punch_in[sc.buffer[voice]].recorded then
            if crops.device == 'enc' and crops.mode == 'input' then
                local n, d = table.unpack(crops.args)
               
                if n == props.n then
                    set_wparam(voice, 'start', get_wparam(voice, 'start') + d*sens*wparams.range)

                    crops.dirty.screen = true
                end
            else
                _st{
                    x = e[props.n].x, y = e[props.n].y, levels = props.levels,
                    text = { 
                        st = format_time(reg.play:get_start(voice, 'seconds'))
                    },
                }
            end
        end
    end
end

local function Length()
    --TODO: adjust list style based on scope
    local _len = Components.screen.list_underline()

    return function(props)
        local sens = props.sensitivity or 0.01
        local voice = props.voice
        
        if sc.punch_in[sc.buffer[voice]].recorded then
            if crops.device == 'enc' and crops.mode == 'input' then
                local n, d = table.unpack(crops.args)

                if n == props.n then
                    set_wparam(voice, 'length', get_wparam(voice, 'length') + d*sens*wparams.range)

                    crops.dirty.screen = true
                end
            else
                _len{
                    x = e[props.n].x, y = e[props.n].y, levels = props.levels,
                    text = { 
                        len = format_time(reg.play:get_length(voice, 'seconds'))
                    },
                }
            end
        end
    end
end

local function Voice(args)
    local n = args.n

    local _old = Patcher.enc_screen.destination(Mparam())
    local _lvl = Patcher.enc_screen.destination(Mparam())
    local _spr = Patcher.enc_screen.destination(Mparam())
    local _rand_lvl = Rand{ voice = n, id = 'lvl' }
    local _rand_spr = Rand{ voice = n, id = 'spr' }

    local _rate = Patcher.enc_screen.destination(Mparam())
    local _st = Patcher.enc_screen.destination(Start())
    local _len = Patcher.enc_screen.destination(Length())
    local _rands_window = Rands_window{ voice = n }
    local _loop = Mparam()

    local _q = Patcher.enc_screen.destination(Mparam())
    local _cut = Patcher.enc_screen.destination(Mparam())
    local _typ = Patcher.enc_screen.destination(Mparam())
    local _rand_cut = Rand{ voice = n, id = 'cut' }
    local _rand_typ = Rand{ voice = n, id = 'type' }

    return function(props)
        if props.tab == 1 then
            _old(mparams:get_id(n, 'old'), active_src, { 
                id = 'old', voice = n, n = 1, levels = { 4, 15 } 
            })
            _lvl(mparams:get_id(n, 'lvl'), active_src, { 
                id = 'lvl', voice = n, n = 2, levels = { 4, 15 } 
            })
            _spr(mparams:get_id(n, 'spr'), active_src, { 
                id = 'spr', voice = n, n = 3, levels = { 4, 15 } 
            })
            _rand_lvl{ n = 2 }
            _rand_spr{ n = 3 }
        elseif props.tab == 2 then
            _rate(mparams:get_id(n, 'bnd'), active_src, { 
                id = 'bnd', name = 'rate', voice = n, n = 1 
            })

            if alt then
                _loop(mparams:get_id(n, 'loop'), active_src, { 
                    id = 'loop', voice = n, n = 3, levels = { 4, 15 } 
                })
            else
                _st(wparams:get_id(n, 'start'), active_src, { 
                    voice = n, n = 2, levels = { 4, 15 } 
                })
                _len(wparams:get_id(n, 'length'), active_src, { 
                    voice = n, n = 3, levels = { 4, 15 } 
                })
                _rands_window{ n = { 2, 3 }, levels = { 4, 15 } }
            end
        elseif props.tab == 3 then
            _q(mparams:get_id(n, 'q'), active_src, { 
                id = 'q', voice = n, n = 1, levels = { 4, 15 } 
            })
            _cut(mparams:get_id(n, 'cut'), active_src, { 
                id = 'cut', voice = n, n = 2, levels = { 4, 15 } 
            })
            _typ(mparams:get_id(n, 'type'), active_src, { 
                id = 'type', voice = n, n = 3, levels = { 4, 15 } 
            })
            _rand_cut{ n = 2 }
            _rand_typ{ n = 3 }
        end
    end
end

local Modal = {}

function Modal.buffer()
    local _header = Screen.text()
    local _length = Screen.text()
    local _free_space = Screen.text()
    local _max_free_space = Screen.text()

    local _export = {
        key = Key.trigger(),
        screen = Screen.text(),
    }
    local _import = {
        key = Key.trigger(),
        screen = Screen.text(),
    }

    return function(props)
        local left, right = x[1] + 1, x[3] - 1
        local n = view.modal_index
        local buf = sc.buffer[n]

        do
            local yy = y[2] + 5
            local x, flow, level = left, 'right', 8
            _header{
                x = x, y = yy, --y = 64/2,
                flow = flow, level = level,
                text = 'BUFFER '..buf,
            } 
            yy = yy + 8

            _length{
                x = x, y = yy, --y = 64/2,
                flow = flow, level = level,
                text = sc.punch_in[buf].recorded and (
                    'length: '..format_time(reg.play:get_length(n, 'seconds'))
                ) or 'empty'
            } 
            yy = yy + 8
            local free_space = format_time(reg.blank[buf]:get_length('seconds'))
            _free_space{
                x = x, y = yy, --y = 64/2,
                flow = flow, level = level,
                text = 'free space: '..free_space
            } 
            yy = yy + 8
            _max_free_space{
                x = x, y = yy, --y = 64/2,
                flow = flow, level = level,
                text = 'max free space: '..(
                    sc.buffer_is_expandable(buf) and format_time(sc.buf_time) or free_space
                )
            } 
        end

        _export.key{
            n = 2, 
            input = function(z) if z==0 then
                view.modal = 'none'

                clock.cancel(screen_clock)
                textentry.enter(textentry_callback, nil, 'file name')
            end end
        }
        _export.screen{
            x = left, y = e[2].y,
            text = 'export',
        } 
        _import.key{
            n = 3, 
            input = function(z) if z==0 then
                view.modal = 'none'

                clock.cancel(screen_clock)
                fileselect.enter(fileselect_dir, fileselect_callback)
            end end
        }
        _import.screen{
            x = right, y = e[3].y,
            text = 'import',
            flow = 'left'
        } 
    end
end

local function App()
    local _alt = Key.momentary()

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

    local _buffer = Screen.list()
    local _preset = Components.screen.list_underline()
    local _page = Screen.glyph()
    local _track = Components.screen.list_highlight()

    local _send_ret = {}
    for i = 1,tracks do _send_ret[i] = Screen.glyph() end

    local _play = Screen.glyph()
    local _loop = Screen.glyph()

    local _level = Components.screen.meter()
    local _old = Components.screen.meter()
    local _spread = Components.screen.dial()

    local _modal = { buffer = Modal.buffer() }

    return function()
        _alt{
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

            _buffer{
                x = x[1], y = y[4], levels = { 2, 4 }, flow = 'right',
                focus = get_param('buffer '..n), margin = 2,
                text = tall and { 1, 2, 3, 4, 5, 6 } or { 1, 2, 3, 4 },
            }
            if recorded then
                _preset{
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

        _page{
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
        _track{
            x = x[0], y = y[2] + 5, flow = 'down', margin = 3, levels = { 4, 10 },
            text = track_names, focus = view.track, fixed_width = 4, nudge = true,
        }

        do
            local y = y[2]
            for i = 1,tracks do
                _send_ret[i]{
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
                        --TODO: display modulated value
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
                _play{
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
                _loop{
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

        if view.modal == 'none' then
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
                                local spec = params:lookup_param('gain 1').controlspec

                                _level{
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

                                _old{
                                    x = x, y = y, length = l, width = 1,
                                    levels = i==view.track and levels_focus or levels,
                                    amount = util.linlin(
                                        spec.minval, spec.maxval, 0, 1, get_mparam(i, 'old')
                                    )
                                }
                            end
                            do
                                local l = k[3].x - e[3].x
                                local x = x[3] - l

                                _spread{
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
                        st = reg.play:get_start(n, 'fraction'), 
                        en = reg.play:get_end(n, 'fraction'),
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
                    local cut_spec = mparams:get_controlspec('cut')
                    local q_spec = mparams:get_controlspec('q')

                    _filtergraph{
                        filter_type = ({ 
                            'lowpass', 'bandpass', 'highpass', 'bypass' 
                        })[
                            get_mparam(n, 'type')
                        ],
                        freq = util.linexp(
                            cut_spec.minval, cut_spec.maxval, 
                            20, 20000, 
                            get_mparam(n, 'cut')
                        ),
                        -- resonance = util.linexp(0, 1, 0.01, 20, mparams:get(n, 'q')),
                        resonance = q_spec:unmap(get_mparam(n, 'q')),
                    }
                end
            end

            _voices[view.track]{ tab = view.page }

        elseif _modal[view.modal] then
            _modal[view.modal]()
        end
    end
end

return App
