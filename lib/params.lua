local all = { 'zone', 'voice', 'global' }
local some = { 'zone', 'voice' }

mparams:add {
    id = 'vol',
    type = 'control', controlspec = cs.def { default = 1, max = 2.5 },
    scopes = all, scope = 'voice',
    action = function(i, v)
        sc.lvlmx[i].vol = v; sc.lvlmx:update(i)
    end
}
mparams:add {
    id = 'old',
    type = 'control', controlspec = cs.def { default = 0.8, max = 1 },
    scopes = all, scope = 'global',
    action = function(i, v)
        sc.oldmx[i].old = v; sc.oldmx:update(i)
    end
}
mparams:add {
    id = 'pan',
    type = 'control', controlspec = cs.def { min = -1, max = 1, default = 0 },
    scopes = all, scope = 'global',
    action = function(i, v)
        sc.panmx[i].pan = v; sc.panmx:update(i)
    end,
    action_global = function(v)
        for i = 1, ndls.voices do
            local scl = ({ -1, 1, -0.5, 0.5 })[i]
            sc.panmx[i].pan = v * scl * 2; sc.panmx:update(i)
        end
    end
}
mparams:add {
    id = 'bnd',
    type = 'control', controlspec = cs.def { min = -1, max = 1, default = 0 },
    scopes = all, scope = 'voice',
    action = function(i, v) sc.ratemx[i].bnd = v; sc.ratemx:update(i) end
}
mparams:add {
    id = 'cut',
    type = 'control', controlspec = cs.def { default = 1, quantum = 1/100/2, step = 0 },
    scopes = all, scope = 'zone',
    action = function(i, v)
        softcut.post_filter_fc(i, util.linexp(0, 1, 20, 20000, v))
    end,
    action_global = function(v)
        for i = 1, ndls.voices do
            local scl = ({ -1, 1, -0.5, 0.5 })[i]
            softcut.post_filter_fc(i, util.linexp(0, 1, 20, 20000, 0.5 + (v * scl / 2)))
        end
    end
}
mparams:add {
    id = 'q',
    type = 'control', controlspec = cs.def { default = 0.4 }, scopes = all, scope = 'voice',
    action = function(i, v)
        softcut.post_filter_rq(i, util.linexp(0, 1, 0.01, 20, 1 - v))
    end
}
local types = { 'lp', 'bp', 'hp', 'dry' }
mparams:add {
    id = 'type',
    type = 'option', options = types, scopes = all, scope = 'zone',
    action = function(i, v)
        for _,k in pairs(types) do softcut['post_filter_'..k](i, 0) end
        softcut['post_filter_'..types[v]](i, 1)
    end
}
-- mparams:add {
--     id = 'aliasing',
--     type = 'control', controlspec = cs.new(), scopes = all, scope = 'global',
--     action = function(i, v)
--         sc.aliasmx[i].aliasing = v; sc.aliasmx:update(i)
--     end
-- }
mparams:add {
    id = 'volt',
    type = 'control', controlspec = cs.def { min = -5, max = 5 }, scopes = all, scope = 'zone',
    action = function(i, v)
        cr.outmx[i] = v; cr.outmx:update(i)
    end
}
mparams:add {
    id = 'alias',
    type = 'binary', behavior = 'toggle', scopes = { 'voice' },
    action = function(i, v)
        sc.aliasmx[i].alias = v; sc.aliasmx:update(i)
    end
}
mparams:add {
    id = 'rec',
    type = 'binary', behavior = 'toggle', scopes = { 'voice' }, hidden = true,
    persistent = false,
    action = function(n, v)
        sc.oldmx[n].rec = v; sc.oldmx:update(n)

        local z = ndls.zone[n]
        if not sc.punch_in[z].recorded then
            sc.punch_in:set(n, z, v)
            if v==0 then mparams.id['play']:set(1, n) end
        elseif sc.lvlmx[n].play == 0 and v == 1 then
            --TODO reset mparams
            sc.punch_in:clear(z)
            sc.punch_in:set(n, z, 1)
        end

        nest.arc.make_dirty()
    end
}
mparams:add {
    id = 'play',
    type = 'binary', behavior = 'toggle', scopes = some, scope = 'voice',
    action = function(n, v)
        local z = ndls.zone[n]
        if v==1 and sc.punch_in[z].recording then
            sc.punch_in:set(n, z, 0)
        end

        sc.lvlmx[n].play = v; sc.lvlmx:update(n)

        nest.arc.make_dirty()
    end
}
local rate = mparams:add {
    id = 'rate',
    type = 'number', min = -7, max = 2, default = 0, scopes = some, scope = 'zone',
    action = function(i, v)
        sc.ratemx[i].oct = v; sc.ratemx:update(i)
    end
}
local rev = mparams:add {
    id = 'rev',
    type = 'binary', behavior = 'toggle', scopes = some, scope = 'zone',
    no_scope_param = true,
    action = function(i, v) sc.ratemx[i].dir = v>0 and -1 or 1; sc.ratemx:update(i) end
}
local dub = mparams:add {
    id = 'dub',
    type = 'binary', behavior = 'toggle', scopes = some, scope = 'zone',
    no_scope_param = true,
    action = function(i, v) sc.oldmx[i].old2 = 1-v; sc.oldmx:update(i) end
}
function rate:set_scope(scope)
    mparam.set_scope(self, scope)
    rev:set_scope(scope)
end
mparams:add {
    id = 'send',
    type = 'binary', behavior = 'toggle', scopes = { 'voice' }, default = 1,
    action = function(i, v) sc.sendmx[i].send = v; sc.sendmx:update() end
}
mparams:add {
    id = 'return',
    type = 'binary', behavior = 'toggle', scopes = { 'voice' },
    action = function(i, v) sc.sendmx[i].ret = v; sc.sendmx:update() end
}

--add metaparam params
params:add_separator('config')
mparams:add_scope_params('scopes')

params:add_separator('ndls')
mparams:add_params()
