params:add_separator('ndls')

params:add {
    id = 'old',
    type = 'control', controlspec = cs.def { default = 0.8, max = 1 },
    action = function(v)
        for i = 1, ndls.voices do
            sc.oldmx[i].old = v; sc.oldmx:update(i)
        end
        nest.screen.make_dirty(); nest.arc.make_dirty()
    end
}
params:add {
    id = 'spread',
    type = 'control', controlspec = cs.def { min = -1, max = 1, default = 0.75 },
    action = function(v)
        for i = 1, ndls.voices do
            local scl = ({ -1, 1, -0.5, 0.5 })[i]
            sc.panmx[i].pan = v * scl * 2; sc.panmx:update(i)
        end
        nest.screen.make_dirty(); nest.arc.make_dirty()
    end
}

for i = 1, ndls.voices do
    params:add {
        id = 'vol '..i,
        type = 'control', controlspec = cs.def { default = 1, max = 2.5 },
        action = function(v)
            sc.lvlmx[i].vol = v; sc.lvlmx:update(i)
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
    --TODO: reset on load
    params:add {
        id = 'rec '..i,
        type = 'binary', behavior = 'toggle', 
        action = function(v)
            local n = i

            sc.oldmx[n].rec = v; sc.oldmx:update(n)

            local z = ndls.zone[n]
            if not sc.punch_in[z].recorded then
                sc.punch_in:set(n, z, v)
                if v==0 then params:set('play '..i, 1) end
            elseif sc.lvlmx[n].play == 0 and v == 1 then
                --TODO reset params
                sc.punch_in:clear(z)
                sc.punch_in:set(n, z, 1)
            end

            nest.grid.make_dirty()
        end
    }
    params:add {
        id = 'play '..i,
        type = 'binary', behavior = 'toggle', 
        action = function(v)
            local n = i

            local z = ndls.zone[n]
            if v==1 and sc.punch_in[z].recording then
                sc.punch_in:set(n, z, 0)
            end

            sc.lvlmx[n].play = v; sc.lvlmx:update(n)

            nest.grid.make_dirty()
        end
    }
    --[[
    params:add {
        id = 'clear '..i,
        type = 'binary',
        behavior = 'trigger',
        action = function()
            local z = ndls.zone[n]
            sc.punch_in:clear(z)
            
            params:set('rec '..i, 0)
        end
    }
    --]]
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
        type = 'binary', behavior = 'toggle',
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
        type = 'binary', behavior = 'toggle', default = 1,
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

params:add {
    id = 'alias',
    type = 'binary', behavior = 'toggle', 
    action = function(v)
        for i = 1, ndls.voices do
            sc.aliasmx[i].alias = v; sc.aliasmx:update(i)
        end
    end
}
