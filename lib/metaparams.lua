local metaparam = {}

function metaparam:new(args)
    if not args.sum then
        if args.type == 'control' then
            args.sum = function(self, a, b, c)
                return self.args.controlspec:map(
                    self.args.controlspec:unmap(a + b + c)
                )
            end
        elseif args.type == 'number' then
            args.sum = function(self, a, b, c)
                return util.clamp(a + b + c, self.args.min, self.args.max)
            end
        elseif args.type == 'option' then
            args.sum = function(self, a, b, c)
                return util.wrap(a + b + c - 1, 1, #self.args.options)
            end
        elseif args.type == 'binary' then
            args.sum = function(self, a, b, c)
                return (a + b + c) % 2
            end
        end
    end
    
    args.resets = args.resets or {
        default = function(param_id)
            local p = params:lookup_param(param_id)
            local silent = true
            params:set(
                param_id, p.default or (p.controlspec and p.controlspec.default) or 0, silent
            )
        end
    }

    args.action = args.action or function() end
    
    local m = setmetatable({}, { __index = self })

    --for k,v in pairs(args) do m[k] = v end
    m.args = args

    m.id = self.args.name

    m.mappable_id = {}
    for t = 1,tracks do
        m.mappable_id[t] = self.args.name..'_track_'..t
    end

    m.base_id = {}
    m.base_setter = {}
    for t = 1,tracks do
        m.base_id[t] = {}
        m.base_setter[t] = {}
        for b = 1,buffers do
            local id = (
                self.args.name
                ..'_track_'..t
                ..'_base_'..b
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
                    self.args.name
                    ..'_track_'..t
                    ..'_buffer_'..b
                    ..'_preset_'..p
                )
                m.preset_id[t][b][p] = id
                m.preset_setter[t][b][p] = multipattern.wrap_set(
                    mpat, id, function(v) params:set(id, v) end
                )
            end
        end
    end

    --TODO: one of these for each track
    m.modulation = function() return 0 end

    return m
end

function metaparam:reset(t, b)
    local b_id = self.base_id[t][b]
    self.args.resets.default(b_id, t, b)

    for p = 1, presets do
        p_id = self.preset_id[t][b][p]
        self.args.resets.default(p_id, t, b)
    end
end

function metaparam:get_base_setter(track)
    local b = sc.buffer[track]
    return self.base_setter[track][b]
end
function metaparam:get_preset_setter(track)
    local b = sc.buffer[track]
    local p = sc.slice:get(track)
    return self.preset_setter[track][b][p]
end
function metaparam:get_base(t)
end
function metaparam:get(track)
    local b = sc.buffer[track]
    local p = sc.slice:get(track)

    return self.args.sum(
        self, 
        params:get(self.base_id[track][b]),
        params:get(self.preset_id[track][b][s]),
        self.modulation()
    )
end

function metaparam:bang(track)
    self.args.action(track, self:get(track))
end

function metaparam:add_base_param(t, b)
    local args = {}
    for k,v in pairs(self.args) do args[k] = v end

    args.id = self.base_id[t][b]
    args.name = args.id
    if args.type == 'control' then
        args.controlspec = self.args.cs_base
    elseif args.type == 'number' then
        args.min = self.args.min_base
        args.max = self.args.max_base
    end
    args.action = function() self:bang(t) end

    params:add(args)
end

function metaparam:add_preset_param(t, b, s)
    local args = {}
    for k,v in pairs(self.args) do args[k] = v end

    args.id = self.preset_id[t][b][p]
    args.name = args.id
    if args.type == 'control' then
        args.controlspec = self.args.cs_preset
    elseif args.type == 'number' then
        args.min = self.args.min_preset
        args.max = self.args.max_preset
    end
    args.action = function() self:bang(t) end

    params:add(args)
end

function metaparam:add_mappable_param(t)
    local args = {}
    for k,v in pairs(self.args) do args[k] = v end

    args.id = self.preset_id[t][b][p]
    args.controlspec = self.args.cs_base
    args.action = function(v)
        for b = 1,buffers do
            params:set(self.base_id[t][b], v)
        end
    end

    params:add(args)
end

--TODO: view option params
--TODO: reset option params

local metaparams = {}

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
function metaparams:reset(track, buffer, id)
    if id then
        self.lookup[id]:reset(track, buffer)
    else
        for _,m in ipairs(self.list) do m:reset(track, buffer) end
    end
end

function metaparams:get_base_setter(track, id)
    return self.lookup[id]:get_base_setter(track)
end
function metaparams:get_preset_setter(track, id)
    return self.lookup[id]:get_preset_setter(track)
end
function metaparams:get_base(track, id)
    return self.lookup[id]:get_base(track)
end
function metaparams:get(track, id)
    return self.lookup[id]:get(track)
end

function metaparams:add_base_params()
    --params:group('values', #self.list * tracks * buffers)
    
    for t = 1, tracks do
        for b = 1,buffers do
            for _,m in ipairs(self.list) do
                m:add_base_param(t)
            end
        end
    end
end
function metaparams:add_preset_params()
    --params:group('values', #self.list * tracks * buffers * presets)

    for t = 1, tracks do
        for b = 1,buffers do
            for p = 1, presets do
                for _,m in ipairs(self.list) do
                    m:add_preset_param(t, b, s)
                end
            end
        end
    end
end
function metaparams:add_mappable_params(t)
    --params:add_separator('track '..t..' (midi mapping)')

    for _,m in ipairs(self.list) do
        m:add_mappable_param(t)
    end
end

return metaparams
