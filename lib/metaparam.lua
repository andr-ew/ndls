local mp = {}
local tap = require 'tabutil'

function mp:new(arg)
    local o = setmetatable({}, { __index = self })
    
    local function slug(id) return string.gsub(id, ' ', '_') end
    local function add(aarg)
        local merge = {}
        for k,v in pairs(arg) do merge[k] = v end
        for k,v in pairs(aarg) do merge[k] = v end
        merge.name = aarg.id
        merge.id = slug(aarg.id)

        params:add(merge)
    end

    o.id = { zone = {}, voice = {}, global = '' }
    o.spec = arg.controlspec
    o.fixed = arg.fixed

    --add always hidden zone params per-voice
    if (not arg.fixed) or (arg.scope == 'zone') then
        for i = 1, ndls.voices do
            o.id.zone[i] = {}
            for j = 1, ndls.zones do
                local id = arg.id +' '+ i +' zone '+ j
                o.id.zone[i][j] = slug(id)

                add { 
                    id = id, 
                    action = function(v)
                        if ndls.zone[i] == j then arg.action(i, v) end
                    end
                }
                params:hide(o.id.zone[i][j])
            end
        end
    end

    --add voice param per-voice
    if (not arg.fixed) or (arg.scope == 'voice') then
        for i = 1, ndls.voices do
            local id = arg.id +' '+ i
            o.id.voice[i] = slug(id)
            add { 
                id = id, 
                action = function(v) arg.action(i, v) end
            }
        end
    end

    --add global param
    if (not arg.fixed) or (arg.scope == 'global') then
        o.id.global = slug(arg.id)
        add { id = id, action = arg.action_global }
    end
    
    if (not arg.fixed) then o:set_scope(arg.scope) else o.scope = arg.scope end

    return o
end

--TODO: bang the zone sope when changing zone
function mp:bang(scope, voice)
    if (scope == nil) or (self.scope = scope) then
        params:bang(self:get_id(voice))
    end
end

function mp:set_scope(scope)
    self.scope = scope

    --show/hide
    local function set(scp, id)
        if scp == scope then params:show(id)
        else params:hide(id) end
    end

    for i,v in ipairs(self.id.voice) do
        set('voice', v)
    end
    set('global', id.global)
end

local scopes = { 'global', 'voice', 'zone' }
local sepocs = tab.invert(ops)

function mp:add_scope_param()
    if not self.fixed then
        params:add {
            type = 'option', id = self.id.global + '_scope', 
            name = self.id.global,
            options = scopes, default = sepocs[self.scope],
            action = function(v)
                self:set_scope(scopes[v])
            end
        }
    end
end

function mp:get_id(vc)
    if self.scope == 'global' then return self.id.global
    elseif self.scope == 'voice' then return self.id.voice[vc]
    else return self.id.zone[vc][ndls.zone[vc]] end
end

function mp:set(v, vc)
    params:set(self:get_id(vc), v)
    metapatterns:watch(v, self:get_id(vc), vc, self.scope)
end

function mp:get(vc)
    return params_get(self:get_id(vc))
end

return mp
