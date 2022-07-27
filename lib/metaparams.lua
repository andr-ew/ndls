local metaparams = {}

metaparams.list = {}
metaparams.lookup = {}

local metaparam = {}

function metaparam:new(args)
    if not args.sum then
        if args.type == 'control' then
            args.sum = function(self, a, b, c)
                return self.args.controlspec:map(a + b + c)
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

    local m = setmetatable({}, { __index = self })

    --for k,v in pairs(args) do m[k] = v end
    m.args = args

    m.mappable_id = {}
    for t = 1,tracks do
        m.mappable_id[t] = self.args.name..'_track_'..t
    end

    m.base_id = {}
    for t = 1,tracks do
        m.base_id[t] = {}
        for b = 1,buffers do
            m.base_id[t][b] = (
                self.args.name
                ..'_track_'..t
                ..'_base_'..b
            )
        end
    end

    m.preset_id = {}
    for t = 1,tracks do
        m.preset_id[t] = {}
        for b = 1,buffers do
            m.preset_id[t][b] = {}
            for p = 1, presets do
                m.preset_id[t][b][p] = (
                    self.args.name
                    ..'_track_'..t
                    ..'_buffer_'..b
                    ..'_preset_'..p
                )
            end
        end
    end

    m.modulation = function() return 0 end

    --TODO: reset callbacks

    table.insert(metaparams.list, m)
    metaparams.lookup[args.id] = m

    return m
end

function metaparam:bang(t)
    --sum base + preset (maybe) of current buf/preset, modulation, send to self.action
end

function metaparam:reset()
    --run reset callback
end

--TODO: set (with multipattern wrappers)
--TODO: get

function metaparam:add_base_param(t, b)
    local args = {}
    for k,v in pairs(self.args) do args[k] = v end

    args.id = self.base_id[t][b]
    args.name = args.id
    args.action = function() self:bang(t) end

    params:add(args)
end

--TODO: preset params should have double the range of base value, clamped/wrapped in summing stage
function metaparam:add_preset_param(t, b, s)
    local args = {}
    for k,v in pairs(self.args) do args[k] = v end

    args.id = self.preset_id[t][b][p]
    args.name = args.id
    args.action = function() self:bang(t) end

    params:add(args)
end

function metaparam:add_mappable_param(t)
    local args = {}
    for k,v in pairs(self.args) do args[k] = v end

    args.id = self.preset_id[t][b][p]
    args.action = function(v)
        for b = 1,buffers do
            params:set(self.base_id[t][b], v)
        end
    end

    params:add(args)
end

--TODO: preset include option params

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
