params:add_separator('config')

params:add_group('randomization', 2 + voices*3)
do
    params:add{
        id = 'len min', type = 'control', 
        controlspec = cs.def{ min = 0, max = 1, default = 0.15 },
    }
    params:add{
        id = 'len max', type = 'control', 
        controlspec = cs.def{ min = 0.5, max = 10, default = 0.75 },
    }

    for i = 1, voices do
        params:add_separator('voice '..i)
        params:add{
            id = 'rand st '..i, type = 'binary', behavior = 'trigger',
            action = function()
                sc.slice:randomize(i, sc.slice:get(i), 'st')
            end
        }
        params:add{
            id = 'rand len '..i, type = 'binary', behavior = 'trigger',
            action = function()
                sc.slice:randomize(i, sc.slice:get(i), 'len')
            end
        }
    end
end

--TODO: input routing per-voice 🧠
local ir_op = { 'left', 'right' }
params:add {
    type = 'option', id = 'input routing', options = ir_op,
    action = function(v)
        sc.inmx.route = ir_op[v]
        for i = 1,voices do sc.inmx:update(i) end
    end
}

params:add {
    id = 'alias',
    type = 'binary', behavior = 'toggle', default = 0,
    action = function(v)
        for i = 1, voices do
            sc.aliasmx[i].alias = v; sc.aliasmx:update(i)
        end
    end
}

params:add{
    type = 'control', id = 'rec transition',
    controlspec = cs.def { default = 1, min = 0, max = 5 },
    action = function(v)
        for i = 1, voices do
            softcut.recpre_slew_time(i, v)
        end
    end
}

for i = 1, voices do
    params:add_separator('voice '..i)

    params:add {
        id = 'vol '..i,
        type = 'control', controlspec = cs.def { default = 1, max = 2.5 },
        action = function(v)
            sc.lvlmx[i].vol = v; sc.lvlmx:update(i)
            nest.screen.make_dirty(); nest.arc.make_dirty()
        end
    }
    params:add {
        id = 'pan '..i,
        type = 'control', 
        controlspec = cs.def { 
            min = -1, max = 1, default = ({ 0, 0.1, -0.3, 0.5 })[i]
        },
        action = function(v)
            sc.panmx[i].pan = v; sc.panmx:update(i)
            nest.screen.make_dirty(); nest.arc.make_dirty()
        end
    }
    params:add {
        --id = 'old',
        id = 'old '..i,
        type = 'control', controlspec = cs.def { default = 0.8, max = 1 },
        action = function(v)
            --for i = 1, voices do
                sc.oldmx[i].old = v; sc.oldmx:update(i)
            --end
            nest.screen.make_dirty(); nest.arc.make_dirty()
        end
    }
    params:add {
        id = 'bnd '..i,
        type = 'control', controlspec = cs.def { min = -1, max = 1, default = 0 },
        action = function(v) 
            sc.ratemx[i].bnd = v; sc.ratemx:update(i) 
            nest.screen.make_dirty(); nest.arc.make_dirty()
        end
    }
    params:add {
        id = 'cut '..i,
        type = 'control', controlspec = cs.def { default = 1, quantum = 1/100/2, step = 0 },
        action = function(v)
            softcut.post_filter_fc(i, util.linexp(0, 1, 20, 20000, v))
            nest.screen.make_dirty(); nest.arc.make_dirty()
        end
    }
    params:add {
        id = 'q '..i,
        type = 'control', controlspec = cs.def { default = 0.4 },
        action = function(v)
            softcut.post_filter_rq(i, util.linexp(0, 1, 0.01, 20, 1 - v))
            nest.screen.make_dirty(); nest.arc.make_dirty()
        end
    }
    local types = { 'lp', 'bp', 'hp', 'dry' }
    params:add {
        id = 'type '..i,
        type = 'option', options = types, 
        action = function(v)
            for _,k in pairs(types) do softcut['post_filter_'..k](i, 0) end
            softcut['post_filter_'..types[v]](i, 1)
            nest.screen.make_dirty(); nest.arc.make_dirty()
        end
    }
    params:add {
        id = 'rec '..i,
        type = 'binary', behavior = 'toggle', 
        action = function(v)
            local n = i

            sc.oldmx[n].rec = v; sc.oldmx:update(n)

            local z = sc.buffer[n]
            if not sc.punch_in[z].recorded then
                sc.punch_in:set(z, v)

                --TODO: refactor reset call into sc.punch_in
                if v==0 and sc.punch_in[z].recorded then 
                    sc.slice:reset(n)
                    params:set('loop '..i, 1) --TODO: won't need this later
                end
            end

            nest.grid.make_dirty()
            nest.screen.make_dirty()
        end
    }
    params:add {
        id = 'clear '..i,
        type = 'binary', behavior = 'trigger', 
        action = function()
            local n = i
            local z = sc.buffer[n]

            params:set('rec '..i, 0) 
            sc.punch_in:clear(z)

            nest.grid.make_dirty()
            nest.screen.make_dirty()
        end
    }
    params:add {
        id = 'loop '..i,
        type = 'binary', behavior = 'toggle', default = 1,
        action = function(v)
            local n = i

            sc.loopmx[n].loop = v; sc.loopmx:update(n)

            nest.grid.make_dirty()
            nest.screen.make_dirty()
        end
    }
    -- params:add {
    --     id = 'play '..i,
    --     type = 'binary', behavior = 'toggle', 
    --     action = function(v)
    --         local n = i

    --         local z = sc.buffer[n]
    --         if v==1 and sc.punch_in[z].recording then
    --             sc.punch_in:set(z, 0)
    --             sc.slice:reset(n)
    --         end

    --         sc.lvlmx[n].play = v; sc.lvlmx:update(n)

    --         nest.grid.make_dirty()
    --         nest.screen.make_dirty()
    --     end
    -- }
    params:add {
        id = 'rate '..i,
        type = 'number', min = -7, max = 2, default = 0, 
        action = function(v)
            sc.ratemx[i].oct = v; sc.ratemx:update(i)
            nest.grid.make_dirty()
        end
    }
    params:add {
        id = 'rev '..i,
        type = 'binary', behavior = 'toggle', 
        action = function(v) 
            sc.ratemx[i].dir = v>0 and -1 or 1; sc.ratemx:update(i) 
            nest.grid.make_dirty()
        end
    }
    params:add {
        id = 'dub '..i,
        type = 'binary', behavior = 'toggle', 
        action = function(v) 
            sc.oldmx[i].old2 = 1-v; sc.oldmx:update(i) 
            nest.grid.make_dirty()
        end
    }
    params:add {
        id = 'send '..i,
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
    params:add {
        id = 'return '..i,
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
    params:add {
        id = 'buffer '..i,
        type = 'number', min = 1, max = buffers, default = i,
        action = function(v)
            --if s[n] ~= v then
            sc.buffer[i] = v; sc.buffer:update(i)
            -- end
        end
    }
    for b = 1,buffers do
        params:add {
            id = 'slice '..i..' buffer '..b,
            type = 'number', min = 1, max = slices, default = 1,
            action = function(v)
                --if s[n] ~= v then
                sc.slice[i][b] = v; sc.slice:update(i, b)
                -- end
            end
        }
    end
    for b = 1,buffers do
        for s = 1, slices do
            params:add {
                id = 'start '..i..' buffer '..b..' slice '..s,
                type = 'control', controlspec = cs.def{ min = 0, max = 1, default = 0 },
                action = function() update_reg(i, b, s) end
            }
            params:add {
                id = 'end '..i..' buffer '..b..' slice '..s,
                type = 'control', controlspec = cs.def{ min = 0, max = 1, default = 1 },
                action = function() update_reg(i, b, s) end
            }
        end
    end
end
