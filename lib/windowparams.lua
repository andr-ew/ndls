local windowparams = {}

local min_v = 0
local max_v = 5
local range_v = max_v - min_v

windowparams.min_v = min_v
windowparams.max_v = max_v
windowparams.range_v = range_v

function windowparams:new()
    local m = setmetatable({}, { __index = self })

    m.preset_id = {}
    for t = 1,tracks do
        m.preset_id[t] = {}
        for b = 1,buffers do
            m.preset_id[t][b] = {}
            for p = 1, presets do
                m.preset_id[t][b][p] = {
                    ['start'] = (
                        'start'
                        ..'_t'..t
                        ..'_buf'..b
                        ..'_pre'..p
                    ),
                    ['length'] = (
                        'length'
                        ..'_t'..t
                        ..'_buf'..b
                        ..'_pre'..p
                    )
                }
            end
        end
    end

    m.reset_func = windowparams.resets.random

    m.min = min_v
    m.max = max_v
    m.range = range_v

    return m
end

-- local start = 0
-- local length = 1

-- local function update_slice(t)
--     reg.play[b][t]:expand()
--     reg.play[b][t]:set_start(st, 'fraction')
--     reg.play[b][t]:set_length(len, 'fraction')
-- end

function windowparams:bang(t)
    --TODO: track scope

    -- local st = patcher.get_destination_plus_param(self.preset_id[t][b][p]['start'])/range_v
    -- local len = patcher.get_destination_plus_param(self.preset_id[t][b][p]['length'])/range_v
    -- local st = params:get(self.preset_id[t][b][p]['start'])/range_v
    -- local len = params:get(self.preset_id[t][b][p]['length'])/range_v

    -- reg.play[b][t]:expand()
    -- reg.play[b][t]:set_start(st, 'fraction')
    -- reg.play[b][t]:set_length(len, 'fraction')

    -- crops.dirty.screen = true; crops.dirty.arc = true

    -- local len_id = self:get_id(t, 'length')
    -- params:set(len_id, params:get(len_id))

    local st_id = self:get_id(t, 'start')
    params:lookup_param(st_id).action(params:get(st_id))

    local len_id = self:get_id(t, 'length')
    params:lookup_param(len_id).action(params:get(len_id))
end

function windowparams:defaultize(t, target, b, p, silent)
    local vc = t
    b = b or sc.buffer[vc]
    p = p or preset:get(t)
    local vc = t
    local sl = p
    
    local do_st = target == 'st' or target == 'both'
    local do_len = target == 'len' or target == 'both'

    local id_start = self.preset_id[t][b][p]['start']
    local id_len = self.preset_id[t][b][p]['length']

    do
        local silent = true
        if do_st then params:set(id_start, min_v, silent) end
        if do_len then params:set(id_len, range_v, silent) end
    end
    
    if not silent then
        self:bang(t)
    end
end

function windowparams:randomize(t, target, b, p, silent)
    local vc = t
    target = target or 'both'
    b = b or sc.buffer[vc]
    p = p or preset:get(t)
    local sl = p

    local b_sl = reg.rec[b]

    local id_start = self.preset_id[t][b][p]['start']
    local id_len = self.preset_id[t][b][p]['length']

    local available = b_sl:get_length()
    local last_s_f = params:get(id_start)
    local last_len_f = params:get(id_len) 
    local ll = b_sl:fraction_to_seconds(last_len_f)

    local do_st = target == 'st' or target == 'both'
    local do_len = target == 'len' or target == 'both'
    local len, len_f, st, st_f
    if do_len then
        local min = math.min(params:get('len min'), params:get('len max'))
        local max = math.max(params:get('len min'), params:get('len max'))
        len = math.random()*(max-min) + min
        len_f = b_sl:seconds_to_fraction(len)
    end
    if do_st then
        local min = 0
        local max = math.max(0, available - (do_len and len or ll))
        st = math.random()*(max-min) + min
        st_f = b_sl:seconds_to_fraction(st)
    end

    local si = true

    if do_st then 
        params:set(id_start, st_f * range_v, si)
    end
    if do_len then 
        params:set(id_len, len_f * range_v, si)
    end

    if not silent then
        self:bang(t)
    end
end

windowparams.resets = {
    default = function(self, t, b, p)
        local silent = true
        self:defaultize(t, 'both', b, p, silent)
    end,
    random = function(self, t, b, p)
        local silent = true
        if p == 1 then
            self:defaultize(t, 'both', b, p, silent)
        else
            self:randomize(t, 'both', b, p, silent)
        end
    end
}
function windowparams:set_reset_presets(func)
    self.reset_func = func
end
function windowparams:reset_presets(t, b)
    for p = 1, presets do
        self.reset_func(self, t, b, p)
    end
end

function windowparams:get(track, id)
    local b = sc.buffer[track]
    local p = sc.slice:get(track)
        
    return params:get(self.preset_id[track][b][p][id], v)
end
function windowparams:get_id(track, id)
    local b = sc.buffer[track]
    local p = sc.slice:get(track)

    return self.preset_id[track][b][p][id]
end
function windowparams:set(track, id, v)
    local b = sc.buffer[track]
    local p = sc.slice:get(track)

    params:set(self.preset_id[track][b][p][id], v)
end

local specs = {
    start = cs.def{ min = min_v, max = max_v, default = min_v, units = 'v' },
    length = cs.def{ min = min_v, max = max_v, default = max_v, units = 'v' }
}

function windowparams:get_controlspec(id)
    return specs[id]
end

function windowparams:preset_params_count() return 2 end
function windowparams:preset_param_args(t, b, p)
    return {
        {
            id = self.preset_id[t][b][p].start, name = 'start',
            type = 'control', controlspec = specs.start,
            action = function(st)
                sc.winmx[t].st = st/range_v; sc.winmx:update(t)
                
                crops.dirty.screen = true; crops.dirty.arc = true
            end
        },
        {
            id = self.preset_id[t][b][p].length, name = 'length',
            type = 'control', controlspec = specs.length,
            action = function(len)
                sc.winmx[t].len = len/range_v; sc.winmx:update(t)
                
                crops.dirty.screen = true; crops.dirty.arc = true
            end
        }
    }
end
function windowparams:add_preset_params(t, b, p)
    local args = self:preset_param_args(t, b, p)

    for _,a in ipairs(args) do params:add(a) end
end

return windowparams
