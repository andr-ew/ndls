local tap = require 'tabutil'

local metaparam = {}

function metaparam:new(arg)
    local o = setmetatable({}, { __index = self })
    
    o.id = { zone = {}, voice = {}, global = nil }
    o.spec = arg.controlspec
    o.scopes = arg.scopes
    o.scope = arg.scope
    o.arg = arg
    o.no_scope_param = arg.no_scope_param

    return o
end

function metaparam:set_scope(scope)
    if tab.contains(self.scopes, scope) then
        self.scope = scope

        --show/hide
        local function set(scp, id)
            if scp == scope then params:show(id)
            else params:hide(id) end
        end

        for i,v in ipairs(self.id.voice) do
            set('voice', v)
        end
        if self.id.global then set('global', self.id.global) end
    end
end

function metaparam:hide()
    if self.id.global then params:hide(self.id.global) end
    for i,v in ipairs(self.id.voice) do params:hide(v) end
end

local function slug(id) return string.gsub(string.gsub(id, ' ', '_'), '/', '-') end

function metaparam:add_params()
    local o = self

    local function add(aarg)
        local merge = {}
        for k,v in pairs(o.arg) do merge[k] = v end
        for k,v in pairs(aarg) do merge[k] = v end
        merge.name = aarg.id
        merge.id = slug(aarg.id)

        params:add(merge)
    end

    --add always hidden zone params per-voice
    if tab.contains(o.scopes, 'zone') then
        for i = 1, ndls.voices do
            o.id.zone[i] = {}
            for j = 1, ndls.zones do
                local id = o.arg.id ..' '.. i ..' zone '.. j
                o.id.zone[i][j] = slug(id)

                add { 
                    id = id, 
                    action = function(v)
                        if ndls.zone[i] == j then o.arg.action(i, v) end
                    end
                }
                params:hide(o.id.zone[i][j])
            end
        end
    end

    --add voice param per-voice
    if tab.contains(o.scopes, 'voice') then
        for i = 1, ndls.voices do
            local id = o.arg.id ..' '.. i
            o.id.voice[i] = slug(id)
            add { 
                id = id, 
                action = function(v) o.arg.action(i, v) end
            }
        end
    end

    --add global param
    if tab.contains(o.scopes, 'global') then
        o.id.global = slug(o.arg.id)
        add { 
            id = o.arg.id, 
            action = o.arg.action_global or function(v) 
                for i = 1, ndls.voices do o.arg.action(i, v) end
            end 
        }
    end
    
    local scope = o.arg.scope or o.scopes[1]
    if #o.scopes > 1 then o:set_scope(scope) else o.scope = scope end
    if o.arg.hidden then self:hide() end
end

function metaparam:add_scope_param()
    if #self.scopes > 1 and not self.no_scope_param then
        local sepocs = tab.invert(self.arg.scopes)
        params:add {
            type = 'option', id = slug(self.arg.id .. '_scope'), 
            name = self.arg.id,
            options = self.scopes, default = sepocs[self.scope],
            action = function(v)
                self:set_scope(self.scopes[v])
            end
        }
    end
end

function metaparam:get_id(vc)
    if self.scope == 'global' then return self.id.global
    elseif self.scope == 'voice' then return self.id.voice[vc]
    else return self.id.zone[vc][ndls.zone[vc]] end
end

function metaparam:set(v, vc)
    params:set(self:get_id(vc), v)
    mpats:watch(v, self:get_id(vc), vc, self.scope)
end

function metaparam:get(vc)
    return params_get(self:get_id(vc))
end

--TODO: bang zone scope params when changing zone
--TODO: copy zone data from last zone when entering a blank zone
function metaparam:bang(scope, voice)
    if (scope == nil) or (self.scope == scope) then
        params:bang(self:get_id(voice))
    end
end

local metaparams = { id = {}, ordered = {} }

function metaparams:add(arg)
    local mp = metaparam:new(arg)
    self.id[arg.id] = mp
    table.insert(self.ordered, mp)
    return mp
end

function metaparams:add_params()
    --if groupname then params:add_group(groupname, #self.ordered) end
    for i,v in ipairs(self.ordered) do v:add_params() end
end

function metaparams:add_scope_params(groupname)
    local n = 0 --11
    for i,v in ipairs(self.ordered) do 
        if #v.scopes > 1 and not v.no_scope_param then n = n + 1 end 
    end
    print(n, #self.ordered)

    if groupname then params:add_group(groupname, n) end
    for i,v in ipairs(self.ordered) do v:add_scope_param() end
end

return metaparams, metaparam
