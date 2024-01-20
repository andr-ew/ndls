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
        action = function(i, id)
            local v = patcher.get_destination_plus_param(id)
            local lvl = volt_amp(v, 4)
            if lvl ~= sc.lvlmx[i].lvl then
                sc.lvlmx[i].lvl = lvl; sc.lvlmx:update(i)
                crops.dirty.screen = true; crops.dirty.arc = true
            end
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
        action = function(i, id)
            local v = patcher.get_destination_plus_param(id)
            local spr = (v/5)*4
            if spr ~= sc.sprmx[i].spr then
                sc.sprmx[i].spr = spr; sc.sprmx:update(i)
                crops.dirty.screen = true; crops.dirty.arc = true
            end
        end
    }
    mparams:add{
        id = 'old',
        type = 'control', 
        controlspec = cs.def{ min = 0, max = 5, default = 4, units = 'v' },
        random_min_default = 5/2, random_max_default = 5,
        default_scope = 'global',
        default_reset_preset_action = 'default',
        action = function(i, id)
            local v = patcher.get_destination_plus_param(id)
            local old = volt_amp(v, 5)
            if old ~= sc.oldmx[i].old then
                sc.oldmx[i].old = old; sc.oldmx:update(i)
                crops.dirty.screen = true; crops.dirty.arc = true
            end
        end
    }
    mparams:add{
        id = 'cut', type = 'control', 
        controlspec = cs.def{ min = 0, max = 7, default = 4.2, units = 'v' },
        random_min_default = 7/2, random_max_default = 7,
        default_scope = 'track',
        default_reset_preset_action = 'random',
        action = function(i, id)
            local v = patcher.get_destination_plus_param(id)
            local cut = v/7
            if cut ~= sc.filtermx[i].cut then
                sc.filtermx[i].cut = cut

                softcut.post_filter_fc(i, util.linexp(0, 1, 20, 22000, cut))
        
                filtergraphs[i].dirty = true
                crops.dirty.screen = true; crops.dirty.arc = true
            end
        end
    }
    mparams:add{
        id = 'qual', type = 'control', 
        controlspec = cs.def{ min = -5, max = 5, default = -5, units = 'v' },
        random_min_default = -5, random_max_default = 4,
        default_scope = 'track',
        default_reset_preset_action = 'default',
        action = function(i, id)
            local v = patcher.get_destination_plus_param(id)
            local qual = v/5
            if qual ~= sc.filtermx[i].qual then
                sc.filtermx[i].qual = qual; sc.filtermx:update(i)
                crops.dirty.screen = true; crops.dirty.arc = true
            end
        end
    }
    mparams:add{
        id = 'crv', type = 'control', 
        controlspec = cs.def{ min = -5, max = 5, default = -5, units = 'v' },
        random_min_default = -5, random_max_default = 5,
        default_scope = 'track',
        default_reset_preset_action = 'default',
        action = function(i, id)
            local v = patcher.get_destination_plus_param(id)
            local crv = v/5
            if crv ~= sc.filtermx[i].crv then
                sc.filtermx[i].crv = crv; sc.filtermx:update(i)
                crops.dirty.screen = true; crops.dirty.arc = true
            end
        end
    }
    -- local types = { 'lp', 'bp', 'hp', 'dry' }
    -- mparams:add{
    --     id = 'type', type = 'option', options = types, 
    --     default_scope = 'track',
    --     default_reset_preset_action = 'random',
    --     action = function(i, id)
    --         local v = patcher.get_destination_plus_param(id)
    --         local typ = v
    --         if typ ~= sc.filtermx[i].typ then
    --             sc.filtermx[i].typ = typ

    --             for _,k in pairs(types) do softcut['post_filter_'..k](i, 0) end
    --             softcut['post_filter_'..types[v]](i, 1)
    --             crops.dirty.screen = true; crops.dirty.arc = true
    --         end
    --     end
    -- }
    mparams:add{
        id = 'loop',
        type = 'binary', behavior = 'toggle', 
        default = 1, 
        default_scope = 'track',
        default_reset_preset_action = 'default',
        action = function(i, id)
            local v = patcher.get_destination_plus_param(id)
            local loop = v
            if loop ~= sc.loopmx[i].loop then
                sc.loopmx[i].loop = loop; sc.loopmx:update(i)

                crops.dirty.grid = true
                crops.dirty.screen = true
            end
        end
    }
    mparams:add{
        id = 'bnd', name = 'rate',
        type = 'control', controlspec = cs.def{ 
            min = -4, max = 4, default = 1,
            quantum = 1/100/4,
        },
        random_min_default = 0.5, random_max_default = 2,
        default_scope = 'track',
        default_reset_preset_action = 'default',
        scope_id = 'rate_scope',
        action = function(i, id)
            local v = patcher.get_destination_plus_param(id)
            local bnd = v
            if bnd ~= sc.ratemx[i].bnd then
                sc.ratemx[i].bnd = bnd; sc.ratemx:update(i) 
                crops.dirty.screen = true; crops.dirty.arc = true
            end
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
        action = function(i, id)
            local v = patcher.get_destination_plus_param(id)
            local oct = v
            if oct ~= sc.ratemx[i].oct then
                sc.ratemx[i].oct = oct; sc.ratemx:update(i)
                crops.dirty.grid = true
            end
        end
    }
    mparams:add{
        id = 'rev', name = 'rate: reverse',
        type = 'binary', behavior = 'toggle',
        default = 0,
        default_scope = 'track',
        default_reset_preset_action = 'default',
        scope_id = 'rate_scope',
        action = function(i, id) 
            local v = patcher.get_destination_plus_param(id)
            local dir = v>0 and -1 or 1
            if dir ~= sc.ratemx[i].dir then
                sc.ratemx[i].dir = dir; sc.ratemx:update(i) 
                crops.dirty.grid = true
            end
        end
    }
    mparams:add{
        id = 'rate_slew', type = 'control', 
        controlspec = cs.def{ min = 0, max = 2.5, default = 0 },
        default_scope = 'track', hidden = true,
        scope_id = 'rate_scope',
        action = function(i, id)
            local v = patcher.get_destination_plus_param(id)
            local slew = v
            if slew ~= sc.slewmx[i].slew then
                sc.slewmx[i].slew = slew
                sc.slew(i, slew)
            end
        end
    }

    --TODO: send/return as single metaparam (option type)
    --TODO: rec overdub flag
    
    params:add_separator('metaparams')

    params:add_group('global', mparams:global_params_count())
    do
        local args = mparams:global_param_args()
        for _,a in ipairs(args) do patcher.add_source_and_param(a) end
    end

    params:add_group('track', (mparams:track_params_count() + 1) * tracks)
    for t = 1,tracks do
        params:add_separator('metaparams_track_track_'..t, 'track '..t)

        --TODO: wparams add track params
        
        local args = mparams:track_param_args(t)
        for _,a in ipairs(args) do patcher.add_source_and_param(a) end
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
                    for _,a in ipairs(args) do patcher.add_source_and_param(a) end
                end
                do
                    local args = mparams:preset_param_args(t, b, p)
                    for _,a in ipairs(args) do patcher.add_source_and_param(a) end
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

        local function action_post_record()
            local n = i
            local buf = sc.buffer[n]
            local silent = true

            local should_clamp = reg.rec[buf]:get_length('seconds') < params:get('min buffer size')
            local frac = (
                reg.rec[buf]:get_length('seconds') 
                / params:get('min buffer size')
            )

            if should_clamp then
                reg.rec[buf]:set_length(params:get('min buffer size'), 'seconds', silent)
            end
            
            preset:reset(n, silent)

            if should_clamp then for track = 1,tracks do
                local p = 1
                params:set(
                    wparams.preset_id[track][buf][p]['length'], 
                    frac * windowparams.range_v,
                    silent
                )
            end end
            
            preset:bang(n, buf)
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

                        action_post_record()
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
            name = 'play', id = 'play '..i,
            type = 'binary', behavior = 'toggle', 
            action = function(v)
                local n = i

                local buf = sc.buffer[n]
                if v==1 and sc.punch_in[buf].recording then
                    sc.punch_in:set(buf, 0)

                    action_post_record()
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

        do
            local id = 'buffer '..i
            patcher.add_source_and_param{
                name = 'buffer', id = id,
                type = 'number', min = 1, max = buffers, default = i,
                action = function()
                    local v = patcher.get_destination_plus_param(id)
                    sc.buffer[i] = v; sc.buffer:update(i)

                    crops.dirty.arc = true
                    crops.dirty.screen = true
                    crops.dirty.grid = true
                end
            }
        end
        for b = 1,buffers do
            local id = 'preset '..i..' buffer '..b
            patcher.add_source_and_param{
                name = 'buffer '..b..' preset', id = id,
                type = 'number', min = 1, max = presets, default = 1,
                action = function(v)
                    local v = patcher.get_destination_plus_param(id)
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

                -- if v > 0 and params:get('return '..i) > 0 then
                --     sc.sendmx[i].ret = 0; sc.sendmx:update() 
                --     params:set('return '..i, 0, true)
                -- end
                crops.dirty.grid = true
            end
        }
        params:add{
            name = 'return', id = 'return '..i,
            type = 'binary', behavior = 'toggle',
            action = function(v) 
                sc.sendmx[i].ret = v; sc.sendmx:update()

                -- if v > 0 and params:get('send '..i) > 0 then
                --     sc.sendmx[i].send = 0; sc.sendmx:update() 
                --     params:set('send '..i, 0, true)
                -- end
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
        mparams:add_scope_param('qual')
        mparams:add_scope_param('crv')
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

    params:add_group('input routing', voices)
    for i = 1,voices do 
        params:add{
            type = 'option', id = 'input_routing_'..i, name = 'track '..i,
            options = ir_op,
            action = function(v)
                sc.inmx.route = ir_op[v]
                sc.inmx:update(i)
            end,
            allow_pmap = false,
        }
    end

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
        controlspec = cs.def{ default = 0.01, min = 0, max = 5, units = 's' },
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

--add LFO params
for i = 1,2 do
    params:add_separator('lfo '..i)
    -- mod_src.lfos[i]:add_params('lfo_'..i)
end

--add source & destination params
do
    params:add_separator('patcher')

    -- for i = 1,2 do
    --     params:add{
    --         id = 'patcher_source_'..i, name = 'source '..i,
    --         type = 'option', options = patcher.sources,
    --         default = tab.key(patcher.sources, 'crow in '..i)
    --     }
    -- end
    for i = 1,2 do
        params:add{
            id = 'patcher_source_'..i, name = 'source '..i,
            type = 'option', options = patcher.sources,
            default = tab.key(patcher.sources, 'lfo '..i)
        }
    end
    params:add{
        id = 'patcher_source_3', name = 'source 3',
        type = 'option', options = patcher.sources,
        default = tab.key(patcher.sources, 'crow in 1')
    }

    local function action(dest, v)
        mod_src.crow.update()

        crops.dirty.grid = true
        crops.dirty.screen = true
        crops.dirty.arc = true
    end

    params:add_group('assignments', #patcher.destinations)

    patcher.add_assginment_params()
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
            
            mod_src.lfos.reset_params()
    
            params:bang()
        end
    }
    params:add{
        id = 'force clear all buffers', type = 'binary', behavior = 'trigger',
        action = function()
            for i = 1, voices do
                params:set('rec '..i, 0) 
            end
            for b = 1, buffers do
                sc.punch_in:clear(b)
            end
            sc.reset_slices()
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
