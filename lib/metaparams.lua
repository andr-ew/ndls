local metaparam = {}
local metaparams = {}

local scopes = { 'global', 'track', 'preset' }
local sepocs = tab.invert(scopes)

function metaparam:new(args)
    local m = setmetatable({}, { __index = self })

    m.random_min_id = args.id..'_random_min'
    m.random_max_id = args.id..'_random_max'

    if args.type == 'control' then
        args.random_min_default = args.random_min_default or args.cs_preset.minval
        args.random_max_default = args.random_max_default or args.cs_preset.maxval
        args.randomize = function(self, param_id, silent)
            local min = math.min(
                params:get_raw(m.random_min_id), params:get_raw(m.random_max_id)
            )
            local max = math.max(
                params:get_raw(m.random_min_id), params:get_raw(m.random_max_id)
            )
            local rand = math.random()*(max-min) + min

            params:set_raw(param_id, rand, silent)
        end
    elseif args.type == 'number' then
        args.random_min_default = args.random_min_default or args.min_preset
        args.random_max_default = args.random_max_default or args.max_preset
        args.randomize = function(self, param_id, silent)
            local min = math.min(
                params:get(m.random_min_id), params:get(m.random_max_id)
            )
            local max = math.max(
                params:get(m.random_min_id), params:get(m.random_max_id)
            )
            local rand = math.random(min, max)

            params:set(param_id, rand, silent)
        end
    elseif args.type == 'option' then
        args.randomize = function(self, param_id, silent)
            local min = 1
            local max = #self.args.options
            local rand = math.random(min, max)

            params:set(param_id, rand, silent)
        end
    elseif args.type == 'binary' then
        args.randomize = function(self, param_id, silent)
            --TODO: probabalility
            local rand = math.random(0, 1)

            params:set(param_id, rand, silent)
        end
    end
    
    args.default_scope = args.default_scope or 'track'

    args.action = args.action or function() end
    
    --for k,v in pairs(args) do m[k] = v end
    m.args = args

    m.id = args.id

    m.scope_id = args.id..'_scope'

    m.global_id = args.id..'_global'

    --TODO: slew time data
    
    m.track_id = {}
    m.track_setter = {}
    for t = 1,tracks do
        local id = (
            args.id
            ..'_track'..t
        )
        m.track_id[t] = id
        m.track_setter[t] = multipattern.wrap_set(
            mpat, id, function(v) params:set(id, v) end
        )
    end
    m.preset_id = {}
    m.preset_setter = {}
    for t = 1,tracks do
        m.preset_id[t] = {}
        m.preset_setter[t] = {}
        for b = 1,buffers do
            m.preset_id[t][b] = {}
            m.preset_setter[t][b] = {}
            for p = 1, presets do
                local id = (
                    args.id
                    ..'_t'..t
                    ..'_buf'..b
                    ..'_pre'..p
                )
                m.preset_id[t][b][p] = id
                m.preset_setter[t][b][p] = multipattern.wrap_set(
                    mpat, id, 
                    function(v) params:set(id, v) end
                )
            end
        end
    end

    return m
end

function metaparam:get_scope()
    return scopes[params:get(self.scope_id)]
end

--TODO: add a callback assignment, same as reset/set_reset
-- function metaparam:set_randomize(func)
--     self.args.randomize = func
-- end
function metaparam:randomize(t, b, p, silent)
    b = b or sc.buffer[t]
    p = p or preset:get(t)

    local scope = self:get_scope()

    local p_id = scope == 'preset' and self.preset_id[t][b][p] or self.track_id[t]
    self.args.randomize(self, p_id, silent)
end

local function reset_default(self, param_id)
    local p = params:lookup_param(param_id)
    local silent = true
    params:set(
        param_id, p.default or (p.controlspec and p.controlspec.default) or 0, silent
    )
end

local function reset_random(self, param_id, t, b, p) local silent = true
    if p == 1 then
        reset_default(self, param_id)
    else
        self:randomize(t, b, p, silent)
    end
end

function metaparam:reset_presets(t, b)
    local scope = self:get_scope()

    if scope == 'preset' then
        for p = 1, presets do
            local p_id = self.preset_id[t][b][p]
            reset_random(self, p_id, t, b, p)
        end
    end
end
            
function metaparam:get_setter(track)
    local scope = self:get_scope()
    local b = sc.buffer[track]
    local p = preset:get(track)

    if scope == 'preset' then
        --if ignore_pattern then return function(v) params:set(self.preset_id[track][b][p], v) end
        return self.preset_setter[track][b][p] 
    elseif scope == 'track' then
        --if ignore_pattern then return function(v) params:set(self.base_id[track][b], v) end
        return self.track_setter[track]
    elseif scope == 'global' then
        return function(v) params:set(self.global_id, v) end
    end
end

function metaparam:set(track, v)
    self:get_setter(track)(v)
end

function metaparam:get(track)
    local scope = self:get_scope()

    if scope == 'global' then
        return params:get(self.global_id)
    elseif scope == 'track' then
        return params:get(self.track_id[track])
    elseif scope == 'preset' then
        local b = sc.buffer[track]
        local p = sc.slice:get(track)

        return params:get(self.preset_id[track][b][p])
    end
end
function metaparam:get_controlspec(scope)
    return self.args.controlspec
end
function metaparam:get_options()
    return self.args.options
end

for _, name in ipairs{ 'min', 'max', 'default' } do
    metaparam['get_'..name] = function(self, scope)
        return self.args[name]
    end
end

function metaparam:bang(track)
    self.args.action(track, self:get(track))
end

function metaparam:add_global_param()
    local args = {}
    for k,v in pairs(self.args) do args[k] = v end

    args.id = self.global_id
    args.name = args.id
    args.action = function() 
        for i = 1, tracks do
            self:bang(t) 
        end
    end
    
    params:add(args)
end
function metaparam:add_track_param(t)
    local args = {}
    for k,v in pairs(self.args) do args[k] = v end

    args.id = self.track_id[t]
    args.name = args.id
    args.action = function() self:bang(t) end
    
    params:add(args)
end
function metaparam:add_preset_param(t, b, p)
    local args = {}
    for k,v in pairs(self.args) do args[k] = v end

    args.id = self.preset_id[t][b][p]
    args.name = args.id
    args.action = function() self:bang(t) end

    params:add(args)
end

function metaparam:add_scope_param()
    params:add{
        name = id, id = self.scope_id, type = 'option',
        options = scopes, default = sepocs[self.args.default_scope],
        action = function()
            for i = 1, tracks do
                self:bang(t) 
            end
        end,
        allow_pmap = false,
    }
end

function metaparam:add_random_range_params()
    params:add_separator(self.args.id)

    local min, max
    if self.args.type == 'number' then
        min = self.args.min_preset
        max = self.args.max_preset
    end

    params:add{
        id = self.random_min_id, type = self.args.type, name = 'min',
        controlspec = self.args.type == 'control' and cs.def{
            min = self.args.cs_preset.minval, max = self.args.cs_preset.maxval, 
            default = self.args.random_min_default
        },
        min = min, max = max, default = self.args.type == 'number' and self.args.random_min_default,
        allow_pmap = false,
    }
    params:add{
        id = self.random_max_id, type = self.args.type, name = 'max',
        controlspec = self.args.type == 'control' and cs.def{
            min = self.args.cs_preset.minval, max = self.args.cs_preset.maxval, 
            default = self.args.random_max_default
        },
        min = min, max = max, default = self.args.type == 'number' and self.args.random_max_default,
        allow_pmap = false,
    }
    --TODO: probabalility for binary type
end

function metaparams:new()
    local ms = setmetatable({}, { __index = self })

    ms.list = {}
    ms.lookup = {}

    return ms
end

function metaparams:add(args)
    local m = metaparam:new(args)

    table.insert(self.list, m)
    self.lookup[m.id] = m
end

function metaparams:bang(track, id)
    if id then
        self.lookup[id]:bang(track)
    else
        for _,m in ipairs(self.list) do m:bang(track) end
    end
end

function metaparams:reset_presets(track, buffer, id)
    if id then
        self.lookup[id]:reset(track, buffer)
    else
        for _,m in ipairs(self.list) do m:reset(track, buffer) end
    end
end

-- function metaparams:set_randomize(id, func)
--     return self.lookup[id]:set_randomize(func)
-- end
function metaparams:randomize(track, id, buffer, preset, silent)
    return self.lookup[id]:randomize(track, buffer, preset, silent)
end

function metaparams:get_setter(track, id)
    return self.lookup[id]:get_setter(track)
end
function metaparams:set(track, id, v)
    return self.lookup[id]:set(track, v)
end
function metaparams:get_controlspec(id)
    return self.lookup[id]:get_controlspec()
end
function metaparams:get_options(id)
    return self.lookup[id]:get_options()
end
for _, name in ipairs{ 'min', 'max', 'default' } do
    local f_name = 'get_'..name
    metaparams[f_name] = function(self, id)
        local m = self.lookup[id]
        return m[f_name](m)
    end
end
function metaparams:get(track, id)
    return self.lookup[id]:get(track)
end

function metaparams:global_params_count() return #self.list end
function metaparams:add_global_params()
    for _,m in ipairs(self.list) do 
        local id = m:add_global_param() 
    end
end
function metaparams:track_params_count() return (#self.list + 1) * tracks end
function metaparams:add_track_params()
    for t = 1, tracks do
        params:add_separator('track '..t)
        for _,m in ipairs(self.list) do
            m:add_track_param(t)
        end
    end
end
function metaparams:preset_params_count() return (#self.list + 1) * tracks * buffers * presets end
function metaparams:add_preset_params()
    for t = 1, tracks do
        for b = 1,buffers do
            for p = 1, presets do
                params:add_separator('track '..t..', buffer '..b..', preset '..p)
                for _,m in ipairs(self.list) do
                    m:add_preset_param(t, b, p)
                end
            end
        end
    end
end

function metaparams:scope_params_count() return #self.list end
function metaparams:add_scope_params()
    for _,m in ipairs(self.list) do 
        local id = m:add_scope_param() 
    end
end
function metaparams:random_range_params_count()
    local n = 0
    for _,m in ipairs(self.list) do 
        if m.args.type == 'number' or m.args.type == 'control' then
            n = n + 3
        end
    end

    return n
end
function metaparams:add_random_range_params()
    for _,m in ipairs(self.list) do 
        --TODO: add for binary type
        if m.args.type == 'number' or m.args.type == 'control' then
            m:add_random_range_params() 
        end
    end
end

return metaparams
