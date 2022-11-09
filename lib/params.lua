-- add normal params
do
    params:add_separator('params_sep','params')

    --TODO: divide into a few sensible groups (rec & play, buffers & presets, send & return)
    params:add_group('params', (6 + buffers + 1) * tracks)

    for i = 1, voices do 
        params:add_separator('params_track_'..i, 'track '..i)

        params:add{
            name = 'rec', id = 'rec '..i,
            type = 'binary', behavior = 'toggle', 
            action = function(v)
                local n = i

                sc.oldmx[n].rec = v; sc.oldmx:update(n)

                local z = sc.buffer[n]
                --if not sc.punch_in[z].recorded then
                --    sc.punch_in:set(z, v)

                --    --TODO: refactor reset call into sc.punch_in
                --    if v==0 and sc.punch_in[z].recorded then 
                --        preset:reset(n)
                --    end
                --end
                if not sc.punch_in[z].recorded then
                    sc.punch_in:set(z, v)

                    if v==0 and sc.punch_in[z].recorded then 
                        preset:reset(n)
                        params:set('play '..i, 1) 
                    end
                elseif sc.lvlmx[n].play == 0 and v == 1 then
                    sc.punch_in:clear(z)
                    sc.punch_in:set(z, 1)
                end


                nest.grid.make_dirty()
                nest.screen.make_dirty()
            end
        }
        params:add {
            id = 'play '..i,
            type = 'binary', behavior = 'toggle', 
            action = function(v)
                local n = i

                local z = sc.buffer[n]
                if v==1 and sc.punch_in[z].recording then
                    sc.punch_in:set(z, 0)
                end

                sc.lvlmx[n].play = v; sc.lvlmx:update(n)

                nest.grid.make_dirty()
                nest.screen.make_dirty()
            end
        }
        params:add{
            name = 'clear', id = 'clear '..i,
            type = 'binary', behavior = 'trigger', 
            action = function()
                local n = i
                local b = sc.buffer[n]

                params:set('rec '..i, 0) 
                sc.punch_in:clear(b)

                nest.grid.make_dirty()
                nest.screen.make_dirty()
            end
        }

        params:add{
            name = 'bend', id = 'bnd '..i,
            type = 'control', controlspec = cs.def{ min = -1, max = 1, default = 0 },
            action = function(v) 
                sc.ratemx[i].bnd = v; sc.ratemx:update(i) 
                nest.screen.make_dirty(); nest.arc.make_dirty()
            end
        }
        params:add{
            name = 'buffer', id = 'buffer '..i,
            type = 'number', min = 1, max = buffers, default = i,
            action = function(v)
                sc.buffer[i] = v; sc.buffer:update(i)

                nest.arc.make_dirty()
                nest.screen.make_dirty()
                nest.grid.make_dirty()
            end
        }
        for b = 1,buffers do
            params:add{
                name = 'buffer '..b..' preset', id = 'preset '..i..' buffer '..b,
                type = 'number', min = 1, max = presets, default = 1,
                action = function(v)
                    preset[i][b] = v; preset:update(i, b)

                    nest.arc.make_dirty()
                    nest.screen.make_dirty()
                    nest.grid.make_dirty()
                end
            }
        end
        params:add{
            name = 'send', id = 'send '..i,
            type = 'binary', behavior = 'toggle', default = 1,
            action = function(v) 
                sc.sendmx[i].send = v; sc.sendmx:update() 

                if v > 0 and params:get('return '..i) > 0 then
                    sc.sendmx[i].ret = 0; sc.sendmx:update() 
                    params:set('return '..i, 0, true)
                end
                nest.grid.make_dirty()
            end
        }
        params:add{
            name = 'return', id = 'return '..i,
            type = 'binary', behavior = 'toggle',
            action = function(v) 
                sc.sendmx[i].ret = v; sc.sendmx:update()

                if v > 0 and params:get('send '..i) > 0 then
                    sc.sendmx[i].send = 0; sc.sendmx:update() 
                    params:set('send '..i, 0, true)
                end
                nest.grid.make_dirty()
            end
        }
    end
end

-- add metaparams
do
    --TODO: switch to decibels / exp
    mparams:add{
        id = 'vol',
        type = 'control', controlspec = cs.def{ default = 1, max = 2.5 },
        random_min_default = 0.5, random_max_default = 1.5,
        default_scope = 'track',
        action = function(i, v)
            sc.lvlmx[i].vol = v; sc.lvlmx:update(i)
            nest.screen.make_dirty(); nest.arc.make_dirty()
        end
    }
    mparams:add{
        id = 'pan',
        type = 'control', 
        controlspec = cs.def{ 
            min = -1, max = 1, default = 0,
        },
        default_scope = 'track',
        random_min_default = -1, random_max_default = 1,
        action = function(i, v)
            sc.panmx[i].pan = v; sc.panmx:update(i)
            nest.screen.make_dirty(); nest.arc.make_dirty()
        end
    }
    mparams:add{
        id = 'old',
        type = 'control', 
        controlspec = cs.def{ default = 0.8, max = 1 },
        random_min_default = 0.5, random_max_default = 1,
        default_scope = 'track',
        action = function(i, v)
            sc.oldmx[i].old = v; sc.oldmx:update(i)
            nest.screen.make_dirty(); nest.arc.make_dirty()
        end
    }
    mparams:add{
        id = 'cut', type = 'control', 
        controlspec = cs.def{ min = 0, max = 1, default = 1, quantum = 1/100/2, step = 0 },
        random_min_default = 0.5, random_max_default = 1,
        default_scope = 'track',
        action = function(i, v)
            softcut.post_filter_fc(i, util.linexp(0, 1, 20, 20000, v))
            nest.screen.make_dirty(); nest.arc.make_dirty()
        end
    }
    mparams:add{
        id = 'q', type = 'control', 
        controlspec = cs.def{ min = 0, max = 1, default = 0.4 },
        random_min_default = -0.3, random_max_default = 0.3,
        default_scope = 'track',
        action = function(i, v)
            softcut.post_filter_rq(i, util.linexp(0, 1, 0.01, 20, 1 - v))
            nest.screen.make_dirty(); nest.arc.make_dirty()
        end
    }
    local types = { 'lp', 'bp', 'hp', 'dry' }
    mparams:add{
        id = 'type', type = 'option', options = types, 
        default_scope = 'track',
        action = function(i, v)
            for _,k in pairs(types) do softcut['post_filter_'..k](i, 0) end
            softcut['post_filter_'..types[v]](i, 1)
            nest.screen.make_dirty(); nest.arc.make_dirty()
        end
    }
    mparams:add{
        id = 'loop',
        type = 'binary', behavior = 'toggle', 
        default = 1, 
        default_scope = 'preset',
        action = function(n, v)
            sc.loopmx[n].loop = v; sc.loopmx:update(n)

            nest.grid.make_dirty()
            nest.screen.make_dirty()
        end
    }
    mparams:add{
        id = 'rate',
        type = 'number', 
        min = -7, max = 2, default = 0, 
        random_min_default = -1, random_max_default = 1,
        default_scope = 'preset',
        action = function(i, v)
            sc.ratemx[i].oct = v; sc.ratemx:update(i)
            nest.grid.make_dirty()
        end
    }
    mparams:add{
        id = 'rev',
        type = 'binary', behavior = 'toggle',
        default = 0,
        default_scope = 'preset',
        action = function(i, v) 
            sc.ratemx[i].dir = v>0 and -1 or 1; sc.ratemx:update(i) 
            nest.grid.make_dirty()
        end
    }

    --TODO: build into rate mparam slew data or just hide
    mparams:add{
        id = 'rate_slew', type = 'control', 
        controlspec = cs.def{ min = 0, max = 2.5, default = 0 },
        default_scope = 'preset',
        action = function(i, v)
            sc.slew(i, v)
        end
    }

    --TODO: send/return as single metaparam (option type)
    --TODO: rec overdub flag
    
    params:add_separator('metaparams')

    params:add_group('global', mparams:global_params_count())
    mparams:add_global_params()

    params:add_group('track', (mparams:track_params_count() + 1) * tracks)
    for t = 1,tracks do
        params:add_separator('metaparams_track_track_'..t, 'track '..t)
        --TODO: wparams add track params
        mparams:add_track_params(t)
    end
    params:add_group(
        'preset',
        (mparams:preset_params_count() + wparams:preset_params_count() + 1) 
        * tracks * buffers * presets
    )
    for t = 1,tracks do
        for b = 1,buffers do
            for p = 1, presets do
                params:add_separator('track '..t..', buffer '..b..', preset '..p)
                wparams:add_preset_params(t, b, p)
                mparams:add_preset_params(t, b, p)
            end
        end
    end
end

-- add metaparam options
do
    params:add_separator('metaparam options')

    do
        params:add_group('scopes', mparams:scope_params_count())
        mparams:add_scope_params()
    end

    do
        params:add_group('randomization', 2 + mparams:random_range_params_count())

        params:add{
            id = 'len min', name = 'len min', type = 'control', 
            controlspec = cs.def{ min = 0, max = 1, default = 0.15 },
            allow_pmap = false,
        }
        params:add{
            id = 'len max', name = 'len max', type = 'control', 
            controlspec = cs.def{ min = 0.5, max = 10, default = 0.75 },
            allow_pmap = false,
        }

        mparams:add_random_range_params()
    end

    do
        params:add_group('initial preset values', 10)
    
        do
            local names = { 'random', 'default' }
            local funcs = { windowparams.resets.random, windowparams.resets.default }
            params:add{
                id = 'window_reset', name = 'st + len', type = 'option',
                options = names, default = 1, allow_pmap = false,
                action = function(v)
                    wparams:set_reset_presets(funcs[v])
                end
            }
        end

        local function add_reset_param(id, names, funcs)
            params:add{
                id = id..'_reset', name = id, type = 'option',
                options = names, default = 1, allow_pmap = false,
                action = function(v)
                    mparams:set_reset_presets(id, funcs[v])
                end
            }
        end

        do
            local id = 'old'
            add_reset_param(
                id,
                { 'default', 'random' },
                { metaparams.resets.default, metaparams.resets.random }
            )
        end
        do
            local id = 'vol'
            add_reset_param(
                id,
                { 'default', 'random' },
                { metaparams.resets.default, metaparams.resets.random }
            )
        end
        do
            local id = 'pan'
            add_reset_param(
                id,
                { 'random', 'default' },
                { metaparams.resets.random, metaparams.resets.default }
            )
        end
        do
            local id = 'q'
            add_reset_param(
                id,
                { 'default', 'random' },
                { metaparams.resets.default, metaparams.resets.random }
            )
        end
        do
            local id = 'cut'
            add_reset_param(
                id,
                { 'random', 'default' },
                { metaparams.resets.random, metaparams.resets.default }
            )
        end
        do
            local id = 'type'
            add_reset_param(
                id,
                { 'default', 'random' },
                { metaparams.resets.default, metaparams.resets.random }
            )
        end
        do
            local id = 'loop'
            add_reset_param(
                id,
                { 'default', 'random' },
                { metaparams.resets.default, metaparams.resets.random }
            )
        end
        do
            local id = 'rate'
            add_reset_param(
                id,
                { 'default', 'random' },
                { metaparams.resets.default, metaparams.resets.random }
            )
        end
        do
            local id = 'rev'
            add_reset_param(
                id,
                { 'default', 'random' },
                { metaparams.resets.default, metaparams.resets.random }
            )
        end
    end

    --TODO: slew group
end

-- add softcut options
do
    params:add_separator('softcut options')

    --TODO: input routing per-voice 🧠
    local ir_op = { 'left', 'right' }
    params:add{
        type = 'option', id = 'input routing', options = ir_op,
        action = function(v)
            sc.inmx.route = ir_op[v]
            for i = 1,voices do sc.inmx:update(i) end
        end,
        allow_pmap = false,
    }

    params:add{
        id = 'alias',
        type = 'binary', behavior = 'toggle', default = 0,
        action = function(v)
            for i = 1, voices do
                sc.aliasmx[i].alias = v; sc.aliasmx:update(i)
            end
        end,
        allow_pmap = false,
    }

    params:add{
        type = 'control', id = 'rec transition',
        controlspec = cs.def{ default = 1, min = 0, max = 5 },
        allow_pmap = false,
        action = function(v)
            for i = 1, voices do
                softcut.recpre_slew_time(i, v)
            end
        end
    }

    --TODO: rate glide enable/disable
end

return params_read, params_bang
