local function Gain()
    local _gain = Arc.control()
    local _fill = Arc.control()

    return function(props) 
        local n = props.voice
        local id = props.id
        local off = props.rotated and 16 or 0
        local xx = { 42 - 4 - off, 42 + 16 + 3 - off }

        _gain{
            -- n = tonumber(arc_vertical and n or x),
            n = props.n,
            sensitivity = 0.5, 
            -- controlspec = params:lookup_param(id).controlspec,
            controlspec = props.controlspec,
            -- state = { params:get(id), params.set, params, id },
            state = props.state,
            levels = { 0, props.levels[1], props.levels[1] },
            -- x = { 33, 33 },
            x = xx,
        }
        if crops.mode == 'redraw' then
            _fill{
                -- n = tonumber(arc_vertical and n or x),
                n = props.n,
                -- controlspec = params:lookup_param(id).controlspec,
                controlspec = props.controlspec,
                state = { 0 },
                levels = { 0, 0, props.levels[2] },
                -- x = { 33, 33 },
                x = xx,
            }
        end
    end
end

local function Cut()
    local _filt = Components.arc.filter()
    local _cutoff = Arc.control()

    return function(props) 
        -- local n = props.voice
        local off = props.rotated and 16 or 0

        if crops.mode == 'input' then
            _cutoff{
                -- n = tonumber(arc_vertical and n or x),
                n = props.n,
                levels = props.levels,
                x = { 42, 24+64 }, sensitivity = 0.25, 
                -- state = of_mparam(n, props.id),
                -- controlspec = mparams:get_controlspec(props.id),
                controlspec = props.controlspec,
                state = props.state,
            }
        end
        _filt{
            -- n = tonumber(arc_vertical and n or x),
            n = props.n,
            levels = props.levels,
            x = { 42 - off, 24+64 - off },
            controlspec = props.controlspec,
            cut = props.cut,
            dry = props.dry,
            lp = props.lp,
            bp = props.bp,
            hp = props.hp,
        }
    end
end

local function Old()
    local _old = Arc.control()

    return function(props) 
        -- local n = props.voice
        -- local spec = mparams:get_controlspec(props.id)
        local spec = props.controlspec
        local off = props.rotated and 16 or 0

        _old{
            n = props.n,
            sensitivity = 0.5, 
            controlspec = spec,
            -- state = of_mparam(n, props.id),
            state = props.state,
            levels = { props.levels[1], props.levels[2], props.levels[2] },
            x = { 42 - 4 + 4 - off, 56 - 4 - off },
        }
    end
end

local function Rate()
    local _rate = Arc.control()
    local _mark = Arc.control()

    return function(props) 
        local spec = props.controlspec
        local xx = { 64 - (5*5) + 1 , 5*5 + 1 }

        if crops.mode == 'redraw' then for i = spec.minval, spec.maxval do
            _mark{
                n = props.n,
                controlspec = spec,
                state = { i },
                levels = { 0, 0, props.levels[1] },
                -- x = { 33, 33 },
                x = xx,
            }
        end end
        _rate{
            n = props.n,
            -- sensitivity = 0.25, 
            controlspec = spec,
            -- state = of_mparam(n, props.id),
            state = props.state,
            levels = { 0, 0, props.levels[2] },
            x = xx,
        }
    end
end

local function Spread()
    local _spr = Arc.control()

    return function(props) 
        local n = props.voice
        local spec = props.controlspec

        if crops.mode == 'redraw' then 
            for i = 1,voices do
                _spr{
                    n = props.n,
                    controlspec = cs.def{ min = -1, max = 1 },
                    state = { props.sprmx[i].pan },
                    levels = { 0, 0, props.levels[i==n and 2 or 1] },
                    -- x = { 33, 33 },
                }
            end 
        else
            _spr{
                n = props.n,
                -- sensitivity = 0.25, 
                controlspec = spec,
                state = props.state,
                -- levels = { 0, 0, props.levels[2] },
            }
        end
    end
end

local function Other()
    local _ctl = Arc.control()

    return function(props) 
        local n = props.voice
        -- local spec = mparams:get_controlspec(props.id)
        local spec = props.controlspec
        local off = props.rotated and 16 or 0

        _ctl{
            x = { 42 - off, 24 - off },
            levels = { 0, props.levels[1], props.levels[2] },
            n = props.n,
            sensitivity = spec.quantum*100, 
            controlspec = spec,
            -- state = of_mparam(n, props.id),
            state = props.state,
        }
    end
end


local function Voice()
    local _gain = Gain()

    local _old = Patcher.arc.destination(Old())
    local _spr = Patcher.arc.destination(Spread())

    local _rate = Patcher.arc.destination(Rate())
    local _st = Patcher.arc.destination(Components.arc.st())
    local _len = Patcher.arc.destination(Components.arc.len())
    
    local _qual = Patcher.arc.destination(Other())
    local _cut = Patcher.arc.destination(Cut())
    -- local _cut = Patcher.arc.destination(Other())
    local _crv = Patcher.arc.destination(Other())

    --TODO: arc2 layout
    return function(props)
        local n = props.voice
        local rotated = props.rotated

        if (not arc2) or view.page == MIX then
            local x = 1
            if arc_view[n][x] > 0 then
                local x = 1
                local id = 'gain '..n
                _gain{ 
                    n = tonumber(arc_vertical and n or x),
                    voice = n,
                    levels = { 4, 15 },
                    rotated = rotated,
                    controlspec = params:lookup_param(id).controlspec,
                    state = { params:get(id), params.set, params, id },
                }
            end
        end

        if view.page == MIX then
            do
                local x = arc2 and 2 or 3
                local id = 'old'
                if arc_view[n][x] > 0 then
                    _old(mparams:get_id(n, id), active_src, { 
                        n = tonumber(arc_vertical and n or x),
                        voice = n,
                        levels = { 4, 15 },
                        rotated = rotated,
                        controlspec = mparams:get_controlspec(id),
                        state = of_mparam(n, id),
                    })
                end
            end
            if not arc2 then
                local x = 4
                local id = 'spr'
                if arc_view[n][x] > 0 then
                    _spr(mparams:get_id(n, id), active_src, { 
                        n = tonumber(arc_vertical and n or x),
                        voice = n,
                        levels = { 4, 15 },
                        rotated = rotated,
                        controlspec = mparams:get_controlspec(id),
                        state = of_mparam(n, id),
                        sprmx = sc.sprmx,
                    })
                end
            end
        elseif view.page == TAPE then
            if not arc2 then
                local x = 2
                local id = 'bnd'
                if arc_view[n][x] > 0 then
                    _rate(mparams:get_id(n, id), active_src, { 
                        n = tonumber(arc_vertical and n or x),
                        voice = n,
                        levels = { 4, 15 },
                        rotated = rotated,
                        controlspec = mparams:get_controlspec(id),
                        state = of_mparam(n, id),
                    })
                end
            end

            local b = sc.buffer[n]
            local recording = sc.punch_in[b].recording
            local recorded = sc.punch_in[b].recorded
            do
                local x = arc2 and 1 or 3
                if arc_view[n][x] > 0 then
                    _st(wparams:get_id(n, 'start'), active_src, {
                        n = tonumber(arc_vertical and n or x),
                        x = { 33, 64+32 }, 
                        levels = { 4, 15 },
                        phase = sc.phase[n].rel,
                        show_phase = sc.lvlmx[n].play == 1,
                        -- sensitivity = 1/1000 * wparams.range,
                        delta_seconds = 1/100,
                        controlspec = wparams:get_controlspec('start'),
                        state = of_wparam(n, 'start'),
                        recording = recording,
                        recorded = recorded,
                        reg = reg,
                        voice = n,
                        rotated = rotated,
                    })
                end
            end
            do
                local x = arc2 and 2 or 4
                if arc_view[n][x] > 0 then
                    local nn = tonumber(arc_vertical and n or x)

                    if (not recorded) and crops.mode == 'input' and crops.device == 'arc' then
                        local nnn, d = table.unpack(crops.args)
                        if nnn == nn and d>0 then
                            manual_punch_in(n)
                        end
                    else
                        _len(wparams:get_id(n, 'length'), active_src, {
                            n = nn,
                            x = { 33, 64+32 }, 
                            phase = sc.phase[n].rel,
                            show_phase = sc.lvlmx[n].play == 1,
                            -- sensitivity = 1/1000 * wparams.range,
                            delta_seconds = 1/100,
                            controlspec = wparams:get_controlspec('length'),
                            state = of_wparam(n, 'length'),
                            levels = { 4, 15 },
                            recording = recording,
                            recorded = recorded,
                            reg = reg,
                            voice = n,
                            rotated = rotated,
                        })
                    end
                end
            end
        elseif view.page == FILTER then
            if not arc2 then
                local x = 2
                local id = 'qual'
                if arc_view[n][x] > 0 then
                    _qual(mparams:get_id(n, id), active_src, { 
                        n = tonumber(arc_vertical and n or x),
                        voice = n,
                        levels = { 4, 15 },
                        rotated = rotated,
                        controlspec = mparams:get_controlspec(id),
                        state = of_mparam(n, id),
                    })
                end
            end
            do
                local x = arc2 and 1 or 3
                local id = 'cut'
                if arc_view[n][x] > 0 then
                    _cut(mparams:get_id(n, id), active_src, { 
                        n = tonumber(arc_vertical and n or x),
                        voice = n,
                        levels = { 8, 15 },
                        rotated = rotated,
                        controlspec = mparams:get_controlspec(id),
                        state = of_mparam(n, id),
                        -- type = get_mparam(n, 'type'),
                        cut = get_mparam(n, id),
                        -- cut = sc.filtermx[n].cut,
                        dry = sc.filtermx[n].dry,
                        lp = sc.filtermx[n].lp,
                        bp = sc.filtermx[n].bp,
                        hp = sc.filtermx[n].hp,
                    })
                end
            end
            do
                local x = arc2 and 2 or 4
                local id = 'crv'
                if arc_view[n][x] > 0 then
                    _crv(mparams:get_id(n, id), active_src, { 
                        n = tonumber(arc_vertical and n or x),
                        voice = n,
                        levels = { 4, 15 },
                        rotated = rotated,
                        controlspec = mparams:get_controlspec(id),
                        state = of_mparam(n, id),
                    })
                end
            end
        end
    end
end

local function App(args)
    local rotated = args.rotated
    local wide = args.grid_wide

    local _voices = {}
    for i = 1,voices do
        _voices[i] = Voice()
    end

    return function()
        for n,_voice in ipairs(_voices) do
            _voice{ voice = n, rotated = rotated }
        end
    end
end

return App
