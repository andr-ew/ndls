local function volt_cutoff(volt)
    return util.linexp(0, 7, 20, 20000, volt)
end
-- local function cutoff_volt(cut)
--     return util.explin(20, 20000, 0, 7, cut)
-- end
local function volt_q(volt, inverse)
    return util.linexp(0, 1, 0.01, 1.5, (inverse and (5 - volt) or volt) / 5)
end

local function ampdb(amp) return math.log(amp, 10) * 20.0 end
local function dbamp(db) return 10.0^(db*0.05) end

local function volt_amp(volt, db0val)
    local minval = -math.huge
    local maxval = 0
    local range = dbamp(maxval) - dbamp(minval)

    local scaled = volt/db0val
    local db = ampdb(scaled * scaled * range + dbamp(minval))
    local amp = dbamp(db)

    return amp
end

-- add metaparams
do
    mparams:add{
        id = 'lvl',
        type = 'control', 
        controlspec = cs.def{ min = 0, max = 5, default = 4, units = 'v' },
        random_min_default = 0, random_max_default = 5,
        default_scope = 'track',
        default_reset_preset_action = 'default',
        action = function(i, v)
            sc.lvlmx[i].lvl = volt_amp(v, 4); sc.lvlmx:update(i)
            crops.dirty.screen = true; crops.dirty.arc = true
        end
    }
    mparams:add{
        id = 'spr',
        type = 'control', 
        controlspec = cs.def{ 
            min = -5, max = 5, default = 0.0, quantum = 1/100/5, units = 'v',
        },
        default_scope = 'global',
        default_reset_preset_action = 'random',
        random_min_default = -5/2, random_max_default = 5/2,
        action = function(i, v)
            sc.sprmx[i].spr = (v/5)*4; sc.sprmx:update(i)
            crops.dirty.screen = true; crops.dirty.arc = true
        end
    }
    mparams:add{
        id = 'old',
        type = 'control', 
        controlspec = cs.def{ min = 0, max = 5, default = 4, units = 'v' },
        random_min_default = 5/2, random_max_default = 5,
        default_scope = 'global',
        default_reset_preset_action = 'default',
        action = function(i, v)
            sc.oldmx[i].old = volt_amp(v, 5); sc.oldmx:update(i)
            crops.dirty.screen = true; crops.dirty.arc = true
        end
    }
    mparams:add{
        id = 'cut', type = 'control', 
        controlspec = cs.def{ min = 0, max = 7, default = 7, units = 'v' },
        random_min_default = 7/2, random_max_default = 7,
        default_scope = 'track',
        default_reset_preset_action = 'random',
        action = function(i, v)
            softcut.post_filter_fc(i, util.linexp(0, 1, 20, 22000, v/7))
            crops.dirty.screen = true; crops.dirty.arc = true
        end
    }
    mparams:add{
        id = 'q', type = 'control', 
        controlspec = cs.def{ min = 0, max = 5, default = 0, units = 'v' },
        random_min_default = 0, random_max_default = 4,
        default_scope = 'global',
        default_reset_preset_action = 'default',
        action = function(i, v)
            softcut.post_filter_rq(i, util.linexp(0, 1, 0.01, 20, (5 - v)/5))
            crops.dirty.screen = true; crops.dirty.arc = true
        end
    }
    local types = { 'lp', 'bp', 'hp', 'dry' }
    mparams:add{
        id = 'type', type = 'option', options = types, 
        default_scope = 'track',
        default_reset_preset_action = 'random',
        action = function(i, v)
            for _,k in pairs(types) do softcut['post_filter_'..k](i, 0) end
            softcut['post_filter_'..types[v]](i, 1)
            crops.dirty.screen = true; crops.dirty.arc = true
        end
    }
    mparams:add{
        id = 'loop',
        type = 'binary', behavior = 'toggle', 
        default = 1, 
        default_scope = 'track',
        default_reset_preset_action = 'default',
        action = function(n, v)
            sc.loopmx[n].loop = v; sc.loopmx:update(n)

            crops.dirty.grid = true
            crops.dirty.screen = true
        end
    }
    mparams:add{
        id = 'bnd', name = 'rate',
        type = 'control', controlspec = cs.def{ 
            min = -10, max = 10, default = 0,
            quantum = 1/100/10,
        },
        random_min_default = -1, random_max_default = 1,
        default_scope = 'track',
        default_reset_preset_action = 'default',
        scope_id = 'rate_scope',
        action = function(i, v)
            sc.ratemx[i].bnd = v; sc.ratemx:update(i) 
            crops.dirty.screen = true; crops.dirty.arc = true
        end
    }
    mparams:add{
        id = 'rate', name = 'rate: octave',
        type = 'number', 
        min = -7, max = 2, default = 0, 
        random_min_default = -1, random_max_default = 1,
        default_scope = 'track',
        default_reset_preset_action = 'default',
        scope_id = 'rate_scope',
        action = function(i, v)
            sc.ratemx[i].oct = v; sc.ratemx:update(i)
            crops.dirty.grid = true
        end
    }
    mparams:add{
        id = 'rev', name = 'rate: reverse',
        type = 'binary', behavior = 'toggle',
        default = 0,
        default_scope = 'track',
        default_reset_preset_action = 'default',
        scope_id = 'rate_scope',
        action = function(i, v) 
            sc.ratemx[i].dir = v>0 and -1 or 1; sc.ratemx:update(i) 
            crops.dirty.grid = true
        end
    }
    mparams:add{
        id = 'rate_slew', type = 'control', 
        controlspec = cs.def{ min = 0, max = 2.5, default = 0 },
        default_scope = 'track', hidden = true,
        scope_id = 'rate_scope',
        action = function(i, v)
            sc.slew(i, v)
        end
    }

    --TODO: send/return as single metaparam (option type)
    --TODO: rec overdub flag
    
    params:add_separator('metaparams')

    local function add_param(args)
        -- local old_action = args.action

        --TODO: round value depending on args.type
        -- local new_action = function()
        --     old_action(params:get(args.id) + patcher.get(id))
        -- end
        -- patcher.add_destination(args.id, new_action)

        -- args.action = function(v)
        --     new_action()
        -- end
        
        params:add(args)
    end    

    params:add_group('global', mparams:global_params_count())
    do
        local args = mparams:global_param_args()
        for _,a in ipairs(args) do add_param(a) end
    end

    params:add_group('track', (mparams:track_params_count() + 1) * tracks)
    for t = 1,tracks do
        params:add_separator('metaparams_track_track_'..t, 'track '..t)

        --TODO: wparams add track params
        
        local args = mparams:track_param_args(t)
        for _,a in ipairs(args) do add_param(a) end
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
                do
                    local args = wparams:preset_param_args(t, b, p)
                    for _,a in ipairs(args) do add_param(a) end
                end
                do
                    local args = mparams:preset_param_args(t, b, p)
                    for _,a in ipairs(args) do add_param(a) end
                end
            end
        end
    end
end

-- add other track params
do
    params:add_separator('params_sep', 'track params')

    params:add_group('gain', tracks)
    for i = 1, voices do
        params:add{
            id = 'gain '..i,
            type = 'control', 
            controlspec = cs.new(-math.huge, 6, 'db', nil, 0, 'dB'),
            action = function(v)
                sc.lvlmx[i].gain = util.dbamp(v); sc.lvlmx:update(i)
                crops.dirty.screen = true; crops.dirty.arc = true
            end
        }
    end

    params:add_group('record & play', 4 * tracks)
    for i = 1, voices do
        params:add_separator('params_r&p_track_'..i, 'track '..i)

        local function action_post_record(n)
            local buf = sc.buffer[n]

            preset:reset(n)

            --clamp to minimum buffer size
            if reg.rec[buf]:get_length('seconds') < params:get('min buffer size') then
                local frac = (
                    reg.rec[buf]:get_length('seconds') 
                    / params:get('min buffer size')
                )
                local silent = true

                reg.rec[buf]:set_length(
                    params:get('min buffer size'), 'seconds', silent
                )
                params:set(wparams:get_id(n, 'length'), frac * windowparams.range_v, silent)
            end
        end

        params:add{
            name = 'rec', id = 'rec '..i,
            type = 'binary', behavior = 'toggle', 
            action = function(v)
                local n = i
                local buf = sc.buffer[n]

                sc.oldmx[n].rec = v; sc.oldmx:update(n)

                if not sc.punch_in[buf].recorded then
                    sc.punch_in:set(buf, v)

                    if v==0 and sc.punch_in[buf].recorded then 
                        params:set('play '..i, 1) 

                        action_post_record(n)
                    end
                elseif sc.lvlmx[n].play == 0 and v == 1 then
                    sc.punch_in:clear(buf)
                    sc.punch_in:set(buf, 1)
                end


                crops.dirty.grid = true
                crops.dirty.screen = true
            end
        }
        params:add {
            id = 'play '..i,
            type = 'binary', behavior = 'toggle', 
            action = function(v)
                local n = i

                local buf = sc.buffer[n]
                if v==1 and sc.punch_in[buf].recording then
                    sc.punch_in:set(buf, 0)

                    action_post_record(n)
                end

                sc.lvlmx[n].play = v; sc.lvlmx:update(n)

                crops.dirty.grid = true
                crops.dirty.screen = true
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

                crops.dirty.grid = true
                crops.dirty.screen = true
            end
        }

    end

    params:add_group('buffer & presets', (1 + buffers + 1) * tracks)
    for i = 1, voices do
        params:add_separator('params_b&p_track_'..i, 'track '..i)

        params:add{
            name = 'buffer', id = 'buffer '..i,
            type = 'number', min = 1, max = buffers, default = i,
            action = function(v)
                sc.buffer[i] = v; sc.buffer:update(i)

                crops.dirty.arc = true
                crops.dirty.screen = true
                crops.dirty.grid = true
            end
        }
        for b = 1,buffers do
            params:add{
                name = 'buffer '..b..' preset', id = 'preset '..i..' buffer '..b,
                type = 'number', min = 1, max = presets, default = 1,
                action = function(v)
                    preset[i][b] = v; preset:update(i, b)

                    crops.dirty.arc = true
                    crops.dirty.screen = true
                    crops.dirty.grid = true
                end
            }
        end
    end
    
    params:add_group('send & return', (2 + 1) * tracks)
    for i = 1, voices do
        params:add_separator('params_s&r_track_'..i, 'track '..i)

        params:add{
            name = 'send', id = 'send '..i,
            type = 'binary', behavior = 'toggle', default = 1,
            action = function(v) 
                sc.sendmx[i].send = v; sc.sendmx:update() 

                if v > 0 and params:get('return '..i) > 0 then
                    sc.sendmx[i].ret = 0; sc.sendmx:update() 
                    params:set('return '..i, 0, true)
                end
                crops.dirty.grid = true
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
                crops.dirty.grid = true
            end
        }
    end
end

-- add metaparam options
do
    params:add_separator('metaparam options')

    do
        params:add_group('scopes', 8)

        mparams:add_scope_param('lvl')
        mparams:add_scope_param('spr')
        mparams:add_scope_param('old')
        mparams:add_scope_param('cut')
        mparams:add_scope_param('q')
        mparams:add_scope_param('type')
        mparams:add_scope_param('loop')
        -- mparams:add_scope_param('bnd')
        -- mparams:add_scope_param('rate')
        -- mparams:add_scope_param('rev')
        -- mparams:add_scope_param('rate_slew')

        local scopes = { 'global', 'track', 'preset' }
        local sepocs = tab.invert(scopes)

        params:add{
            name = 'rate', id = 'rate_scope', type = 'option',
            options = scopes, default = sepocs['track'],
            action = function()
                for t = 1, tracks do
                    -- self:bang(t) 
                    mparams:bang(t, 'bnd')
                    mparams:bang(t, 'rate')
                    mparams:bang(t, 'rev')
                    mparams:bang(t, 'rate_slew')
                end

                -- self:show_hide_params()
                mparams:show_hide_params('bnd')
                mparams:show_hide_params('rate')
                mparams:show_hide_params('rev')
                mparams:show_hide_params('rate_slew')

                _menu.rebuild_params() --questionable?
            end,
            allow_pmap = false,
        }
    end

    do
        local wparam_random_range_params_count = 2
        local wparam_random_targets = { 'st', 'len', 'both' }

        params:add_group(
            'randomization', 
            wparam_random_range_params_count
            + mparams:random_range_params_count() 
            + ((
                (#mparams.list + #wparam_random_targets) * 2 --times two for defautize + randomize
                + 1 --also count the track separator
            ) * voices)
        )

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

        
        for i = 1, voices do
            params:add_separator('params_randomization_track_'..i, 'track '..i)


            for _,target in ipairs(wparam_random_targets) do
                params:add{
                    type = 'binary', behavior = 'trigger', 
                    name = 'randomize '..target, id = 'randomize '..target..' '..i,
                }
                params:add{
                    type = 'binary', behavior = 'trigger', 
                    name = 'defaultize '..target, id = 'defaultize '..target..' '..i,
                }
            end
            for _,m in ipairs(mparams.list) do 
                local id = m.id

                params:add{
                    type = 'binary', behavior = 'trigger', 
                    name = 'randomize '..id, id = 'randomize '..id..' '..i,
                }
                params:add{
                    type = 'binary', behavior = 'trigger', 
                    name = 'defaultize '..id, id = 'defaultize '..id..' '..i,
                }
            end
        end
    end
    do
        params:add_group(
            'initial preset values', 
            1 + mparams:reset_preset_action_params_count()
        )
        do
            local names = { 'random', 'default' }
            local funcs = { windowparams.resets.random, windowparams.resets.default }
            params:add{
                id = 'window_reset', name = 'st + len', type = 'option',
                options = names, default = 1, allow_pmap = false,
                action = function(v)
                    wparams:set_reset_presets(funcs[v])
                    crops.dirty.screen = true
                end
            }
        end

        mparams:add_reset_preset_action_params()
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
        controlspec = cs.def{ default = 1, min = 0, max = 5, units = 's' },
        allow_pmap = false,
        action = function(v)
            for i = 1, voices do
                softcut.recpre_slew_time(i, v)
            end
        end
    }
    
    params:add{
        type = 'control', id = 'min buffer size',
        controlspec = cs.def{ 
            default = 5, min = 0, max = 70, units = 's',
            quantum = 1/70,
        },
        allow_pmap = false,
        action = function(v)
            for i = 1, voices do
                softcut.recpre_slew_time(i, v)
            end
        end
    }

    --TODO: rate glide enable/disable
end

--add pset params
do
    params:add_separator('PSET options')

    params:add{
        id = 'reset all params', type = 'binary', behavior = 'trigger',
        action = function()
            for i = 1, voices do
                params:delta('clear '..i)
            end

            for _,p in ipairs(params.params) do if p.save then
                params:set(p.id, p.default or (p.controlspec and p.controlspec.default) or 0, true)
            end end
    
            params:bang()
        end
    }
    params:add{
        id = 'force clear all buffers', type = 'binary', behavior = 'trigger',
        action = function()
            for i = 1, voices do
                params:delta('clear '..i)
            end
        end
    }
    params:add{
        id = 'overwrite default pset', type = 'binary', behavior = 'trigger',
        action = function()
            print('overwrite default pset param triggered')
            params:write(pset_default_slot, 'default')
        end
    }
    params:add{
        id = 'load last session pset', type = 'binary', behavior = 'trigger',
        action = function()
            params:read(pset_last_session_slot)
        end
    }
    params:add{
        id = 'autosave to default pset', type = 'option', options = { 'no', 'yes' },

        -- this being banged on pset load is v bad. not overwriting default on change might be confusing but I'm just going to leave it out for now if/until I think of a better solution
        -- action = function()
        --     print('overwrite default pset param banged')
        --     params:write(pset_default_slot, 'default')
        -- end
    }
end

return params_read, params_bang
