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

    m.offset_id = {}
    for t = 1,tracks do
        m.offset_id[t] = {}
        for b = 1,buffers do
            m.offset_id[t][b] = (
                self.args.name
                ..'_track_'..t
                ..'_offset_'..b
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

function metaparam:bang()
    --sum offset, preset (maybe), modulation, send to self.action
end

function metaparam:reset()
    --run reset callback
end

--TODO: set (with multipattern wrappers)
--TODO: get

function metaparam:add_offset_param(t, b)
    local args = {}
    for k,v in pairs(self.args) do args[k] = v end

    args.id = self.offset_id[t][b]
    args.name = args.id
    args.action = function() self:bang() end

    params:add(args)
end

function metaparam:add_preset_param(t, b, s)
    local args = {}
    for k,v in pairs(self.args) do args[k] = v end

    args.id = self.preset_id[t][b][p]
    args.name = args.id
    args.action = function() self:bang() end

    params:add(args)
end

function metaparam:add_mappable_param(t)
    local args = {}
    for k,v in pairs(self.args) do args[k] = v end

    args.id = self.preset_id[t][b][p]
    args.action = function(v)
        for b = 1,buffers do
            params:set(self.offset_id[t][b], v)
        end
    end

    params:add(args)
end

--TODO: preset include option params

function metaparams:add_offset_params()
    --params:group('values', #self.list * tracks * buffers)
    
    for t = 1, tracks do
        for b = 1,buffers do
            for _,m in ipairs(self.list) do
                m:add_offset_param(t)
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
