local windowparams = {}

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
                    ['end'] = (
                        'end'
                        ..'_t'..t
                        ..'_buf'..b
                        ..'_pre'..p
                    )
                }
            end
        end
    end

    m.reset_func = windowparams.resets.random

    return m
end

function windowparams:bang(t)
    local b = sc.buffer[t]
    local p = sc.slice:get(t)

    --TODO: track scope
    local st = params:get(self.preset_id[t][b][p]['start'])
    local en = params:get(self.preset_id[t][b][p]['end'])

    reg.play[b][t]:expand()
    reg.play[b][t]:set_start(st, 'fraction')
    reg.play[b][t]:set_end(en, 'fraction')

    crops.dirty.screen = true; crops.dirty.arc = true
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
    local id_end = self.preset_id[t][b][p]['end']

    do
        local silent = true
        if do_st then params:set(id_start, 0, silent) end
        if do_len then params:set(id_end, 1, silent) end
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
    --local p = reg.play[b]

    local id_start = self.preset_id[t][b][p]['start']
    local id_end = self.preset_id[t][b][p]['end']

    local available = b_sl:get_length()
    local last_s_f = params:get(id_start)
    local last_e_f = params:get(id_end)
    local last_len_f = last_e_f - last_s_f
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

    --if do_st then p:expand() end
    if do_st then 
        --p:set_start(st, 'seconds') 
        params:set(id_start, st_f, si)

        if not do_len then 
            --p:set_length(ll) 
            params:set(id_end, st_f + last_len_f, si)
        end
    end
    if do_len then 
        --p:set_length(len, 'seconds') 
        local sst_f = do_st and st_f or last_s_f
        params:set(id_end, sst_f + len_f, si)
    end

    if not silent then
        self:bang(t)
    end
end

windowparams.resets = {
    -- none = function() end,
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
    --self:bang(t) --bang happens via preset:reset()
end

function windowparams:get(track, id, units, abs)
    units = units or 'fraction'

    if id == 'start' then
        return reg.play:get_start(track, units, abs)
    elseif id == 'end' then
        return reg.play:get_end(track, units, abs)
    elseif id == 'length' then
        return reg.play:get_length(track, units)
    end
end
function windowparams:set(track, id, v)
    local b = sc.buffer[track]
    local p = sc.slice:get(track)

    params:set(self.preset_id[track][b][p][id], v)
end

local cs_mappabe_win = cs.def{ min = 0, max = 1, default = 0 }
local cs_mappabe_len = cs.def{ min = -1, max = 0, default = 0 }
local cs_base_win = cs.def{ min = -1, max = 1, default = 0 }
local cs_base_len = cs.def{ min = -1, max = 1, default = 0 }
local cs_preset_st = cs.def{ min = 0, max = 1, default = 0 }
local cs_preset_en = cs.def{ min = 0, max = 1, default = 1 }

function windowparams:preset_params_count() return 2 end
function windowparams:add_preset_params(t, b, p)
    params:add{
        id = self.preset_id[t][b][p]['start'], name = 'start',
        type = 'control', controlspec = cs_preset_st,
        action = function() self:bang(t) end
    }
    params:add{
        id = self.preset_id[t][b][p]['end'], name = 'end',
        type = 'control', controlspec = cs_preset_en,
        action = function() self:bang(t) end
    }
end

return windowparams
