local metaparam = {}
local metaparams = {}

function metaparam:new(args)
    local m = setmetatable({}, { __index = self })

    m.random_min_id = args.id..'_random_min'
    m.random_max_id = args.id..'_random_max'

    if args.type == 'control' then
        args.cs_base = args.cs_base or args.controlspec
        args.cs_preset = args.cs_preset or args.controlspec

        args.sum = args.sum or function(self, a, b, c)
            return self.args.controlspec:map(
                self.args.controlspec:unmap(a + b + c)
            )
        end

        args.random_min_default = args.random_min_default or args.cs_preset.minval
        args.random_max_default = args.random_max_default or args.cs_preset.maxval
        --TODO: probabalility ? i.e. probablility of being not default
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
        args.min_base = args.min_base or args.min
        args.min_preset = args.min_preset or args.min
        args.max_base = args.max_base or args.max
        args.max_preset = args.max_preset or args.max
        args.default_base = args.default_base or args.default
        args.default_preset = args.default_preset or args.default

        args.sum = args.sum or function(self, a, b, c)
            return util.clamp(a + b + math.floor(c), self.args.min, self.args.max)
        end

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
        args.sum = args.sum or function(self, a, b, c)
            local cc = util.clamp(math.floor(c), 0, #self.args.options)
            return util.wrap(a + b + cc - 1, 1, #self.args.options)
        end

        args.randomize = function(self, param_id, silent)
            local min = 1
            local max = #self.args.options
            local rand = math.random(min, max)

            params:set(param_id, rand, silent)
        end
    elseif args.type == 'binary' then
        args.default_base = args.default_base or args.default
        args.default_preset = args.default_preset or args.default

        args.sum = args.sum or function(self, a, b, c)
            return (a + b + math.floor(c)) % 2
        end
        
        args.randomize = function(self, param_id, silent)
            --TODO: probabalility
            local rand = math.random(0, 1)

            params:set(param_id, rand, silent)
        end
    end
    
    args.reset = {
        base = metaparams.resets.none,
        preset = metaparams.resets.default,
    }
    -- args.randomize = function(self, p_id, silent) end

    args.action = args.action or function() end
    
    --for k,v in pairs(args) do m[k] = v end
    m.args = args

    m.id = args.id

    m.mappable_id = {}
    for t = 1,tracks do
        m.mappable_id[t] = args.id..'_track_'..t
    end

    --TODO: slew time data
    
    m.base_id = {}
    m.base_setter = {}
    for t = 1,tracks do
        m.base_id[t] = {}
        m.base_setter[t] = {}
        for b = 1,buffers do
            local id = (
                args.id
                ..'_t'..t
                ..'_buf'..b
                ..'_base'
            )
            m.base_id[t][b] = id
            m.base_setter[t][b] = multipattern.wrap_set(
                mpat, id, function(v) params:set(id, v) end
            )
        end
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

    --TODO: one of these for each track
    m.modulation = function() return 0 end

    return m
end

-- function metaparam:set_randomize(func)
--     self.args.randomize = func
-- end
function metaparam:randomize(t, b, p, silent)
    b = b or sc.buffer[t]
    p = p or preset:get(t)

    local p_id = self.preset_id[t][b][p]
    self.args.randomize(self, p_id, silent, t, b, p)
end


metaparams.resets = {
    none = function() end,
    default = function(self, param_id)
        local p = params:lookup_param(param_id)
        local silent = true
        params:set(
            param_id, p.default or (p.controlspec and p.controlspec.default) or 0, silent
        )
    end,
    random = function(self, param_id, t, b, p)
        local silent = true
        if p == 1 then
            metaparams.resets.default(self, param_id)
        else
            self:randomize(t, b, p, silent)
        end
    end
}
function metaparam:set_reset(scope, func)
    scope = scope or 'preset'

    self.args.reset[scope] = func
end
function metaparam:reset(t, b, scope)
    scope = scope or 'preset'

    if scope == 'preset' then
        for p = 1, presets do
            local p_id = self.preset_id[t][b][p]
            self.args.reset.preset(self, p_id, t, b, p)
        end
    else
        local b_id = self.base_id[t][b]
        self.args.reset.base(self, b_id, t, b)
    end
end
            
function metaparam:get_setter(track, scope, ignore_pattern)
    scope = scope or 'preset'
    local b = sc.buffer[track]
    local p = preset:get(track)

    if scope == 'preset' then
        if ignore_pattern then
            return function(v) params:set(self.preset_id[track][b][p], v) end
        else 
            return self.preset_setter[track][b][p] 
        end
    elseif scope == 'base' then
        if ignore_pattern then
            return function(v) params:set(self.base_id[track][b], v) end
        else 
            return self.base_setter[track][b] 
        end
    end
end

function metaparam:set(track, scope, v, ignore_pattern)
    local b = sc.buffer[track]
    --local p = sc.slice:get(track)

    if scope == 'sum' then
        self:get_setter(track, 'preset', ignore_pattern)(self.args.unsum(
            self, 
            v,
            params:get(self.base_id[track][b]),
            self.modulation()
        ))
    else
        self:get_setter(track, scope, ignore_pattern)(v)
    end
end

function metaparam:get(track, scope)
    scope = scope or 'sum'
    local b = sc.buffer[track]
    local p = sc.slice:get(track)

    if scope == 'sum' then
        return self.args.sum(
            self, 
            params:get(self.base_id[track][b]),
            params:get(self.preset_id[track][b][p]),
            self.modulation()
        )
    elseif scope == 'base' then
        return params:get(self.base_id[track][b])
    elseif scope == 'preset' then
        return params:get(self.preset_id[track][b][p])
    end
end
function metaparam:get_controlspec(scope)
    scope = scope or 'sum'

    if scope == 'sum' then
        return self.args.controlspec
    elseif scope == 'base' then
        return self.args.cs_base
    elseif scope == 'preset' then
        return self.args.cs_preset
    end
end
function metaparam:get_options()
    return self.args.options
end

for _, name in ipairs{ 'min', 'max', 'default' } do
    metaparam['get_'..name] = function(self, scope)
        if scope == 'sum' then
            return self.args[name]
        elseif scope == 'base' then
            return self.args[name..'_base']
        elseif scope == 'preset' then
            return self.args[name..'_preset']
        end
    end
end

function metaparam:bang(track)
    self.args.action(track, self:get(track))
end

function metaparam:add_base_param(t, b)
    local args = {}
    for k,v in pairs(self.args) do args[k] = v end

    args.id = self.base_id[t][b]
    if args.type == 'control' then
        args.controlspec = self.args.cs_base
    elseif args.type == 'number' then
        args.min = self.args.min_base
        args.max = self.args.max_base
        args.default = self.args.default_base
    elseif args.type == 'binary' then
        args.default = self.args.default_base
    end
    args.action = function() self:bang(t) end
    
    print(args.id, t, b)

    params:add(args)
end

function metaparam:add_preset_param(t, b, p)
    local args = {}
    for k,v in pairs(self.args) do args[k] = v end

    args.id = self.preset_id[t][b][p]
    if args.type == 'control' then
        args.controlspec = self.args.cs_preset
    elseif args.type == 'number' then
        args.min = self.args.min_preset
        args.max = self.args.max_preset
        args.default = self.args.default_base
    elseif args.type == 'binary' then
        args.default = self.args.default_preset
    end
    args.action = function() self:bang(t) end

    params:add(args)
end

function metaparam:add_mappable_param(t)
    local args = {}
    for k,v in pairs(self.args) do args[k] = v end

    args.id = 'set_'..self.args.id
    args.name = self.args.id
    args.controlspec = self.args.cs_base
    args.action = function(v)
        for b = 1,buffers do
            params:set(self.base_id[t][b], v)
        end
    end

    params:add(args)
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
    --TODO: probabalility for other types ? i.e. probablility of being not default
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

function metaparams:set_reset(id, scope, func)
    return self.lookup[id]:set_reset(scope, func)
end
function metaparams:reset(track, buffer, scope, id)
    if id then
        self.lookup[id]:reset(track, buffer, scope)
    else
        for _,m in ipairs(self.list) do m:reset(track, buffer, scope) end
    end
end

-- function metaparams:set_randomize(id, func)
--     return self.lookup[id]:set_randomize(func)
-- end
function metaparams:randomize(track, id, buffer, preset, silent)
    return self.lookup[id]:randomize(track, buffer, preset, silent)
end

function metaparams:get_setter(track, id, scope, ignore_pattern)
    return self.lookup[id]:get_setter(track, scope, ignore_pattern)
end
function metaparams:set(track, id, scope, v)
    return self.lookup[id]:set(track, scope, v)
end
function metaparams:get_controlspec(id, scope)
    return self.lookup[id]:get_controlspec(scope)
end
function metaparams:get_options(id)
    return self.lookup[id]:get_options()
end
for _, name in ipairs{ 'min', 'max', 'default' } do
    local f_name = 'get_'..name
    metaparams[f_name] = function(self, id, scope)
        local m = self.lookup[id]
        return m[f_name](m, scope)
    end
end
function metaparams:get(track, id, scope)
    return self.lookup[id]:get(track, scope)
end

function metaparams:base_params_count() return #self.list * tracks * buffers end
function metaparams:add_base_params()
    for t = 1, tracks do
        for b = 1,buffers do
            for _,m in ipairs(self.list) do
                m:add_base_param(t, b)
            end
        end
    end
end
function metaparams:preset_params_count() return #self.list * tracks * buffers * presets end
function metaparams:add_preset_params()
    for t = 1, tracks do
        for b = 1,buffers do
            for p = 1, presets do
                for _,m in ipairs(self.list) do
                    m:add_preset_param(t, b, p)
                end
            end
        end
    end
end

function metaparams:mappable_params_count(t) return #self.list end
function metaparams:add_mappable_params(t)
    for _,m in ipairs(self.list) do m:add_mappable_param(t) end
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
        --TODO: add for binaty type
        if m.args.type == 'number' or m.args.type == 'control' then
            m:add_random_range_params() 
        end
    end
end

return metaparams
