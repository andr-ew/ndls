local windowparams = {}

function windowparams:new()
    local m = setmetatable({}, { __index = self })

    m.modulation = {
        st = function() return 0 end,
        len = function() return 0 end
    }

    m.mappable_id = {}
    for t = 1,tracks do
        m.mappable_id[t] = {
            win = (
                'window'
                ..'_track_'..t
            ),
            len = (
                'length'
                ..'_track_'..t
            )
        }
    end
    m.base_id = {}
    for t = 1,tracks do
        m.base_id[t] = {}
        for b = 1,buffers do
            m.base_id[t][b] = {
                win = (
                    'window'
                    ..'_t'..t
                    ..'_buf'..b
                    ..'_base'
                ),
                len = (
                    'length'
                    ..'_t'..t
                    ..'_buf'..b
                    ..'_base'
                )
            }
        end
    end
    m.preset_id = {}
    for t = 1,tracks do
        m.preset_id[t] = {}
        for b = 1,buffers do
            m.preset_id[t][b] = {}
            for p = 1, presets do
                m.preset_id[t][b][p] = {
                    st = (
                        'start'
                        ..'_t'..t
                        ..'_buf'..b
                        ..'_pre'..p
                    ),
                    en = (
                        'end'
                        ..'_t'..t
                        ..'_buf'..b
                        ..'_pre'..p
                    )
                }
            end
        end
    end

    --TODO: wrapped base setters
    local set_start = {}
    local set_end = {}
    for t = 1, tracks do
        set_start[t] = {}
        set_end[t] = {}

        for b = 1, buffers do
            set_start[t][b] = {}
            set_end[t][b] = {}

            for p = 1, presets do
                set_start[t][b][p] = multipattern.wrap_set(
                    mpat, m.preset_id[t][b][p].st, 
                    function(v) params:set(m.preset_id[t][b][p].st, v) end
                )
                set_end[t][b][p] = multipattern.wrap_set(
                    mpat, m.preset_id[t][b][p].en, 
                    function(v) params:set(m.preset_id[t][b][p].en, v) end
                )
            end
        end
    end

    m.preset_setter_start = set_start
    m.preset_setter_end = set_end

    m.reset_func = windowparams.resets.random

    return m
end

function windowparams:bang(t)
    local b = sc.buffer[t]
    local p = sc.slice:get(t)

    --TODO: sum with base vals, modulation
    local st = params:get(self.preset_id[t][b][p].st)
    local en = params:get(self.preset_id[t][b][p].en)

    reg.play[b][t]:expand()
    reg.play[b][t]:set_start(st, 'fraction')
    reg.play[b][t]:set_end(en, 'fraction')

    nest.screen.make_dirty(); nest.arc.make_dirty()
end

function windowparams:expand(t, b, p, silent)
    b = b or sc.buffer[vc]
    p = p or preset:get(t)
    local vc = t
    local sl = p

    local id_start = self.preset_id[t][b][p].st
    local id_end = self.preset_id[t][b][p].en

    local silent = true
    params:set(id_start, 0, silent)
    params:set(id_end, 1, silent)
    
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

    local b = sc.buffer[vc]
    local b_sl = reg.rec[b]
    --local p = reg.play[b]

    local id_start = self.preset_id[t][b][p].st
    local id_end = self.preset_id[t][b][p].en

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
    none = function() end,
    default = function(self, t, b, p)
        local silent = true
        self:expand(t, b, p, silent)
    end,
    random = function(self, t, b, p)
        local silent = true
        if p == 1 then
            windowparams.resets.default(self, t, b, p)
        else
            self:randomize(t, 'both', b, p, silent)
        end
    end
}

function windowparams:set_reset(scope, func)
    self.reset_func = func
end
function windowparams:reset(t, b) --TODO: scope arg
    for p = 1, presets do
        self.reset_func(self, t, b, p)
    end
    --self:bang(t) --bang happens via preset:reset()
end

function windowparams:get_base_setter(id, t)
end
function windowparams:get_preset_setter(id, track)
    local b = sc.buffer[track]
    local p = sc.slice:get(track)
    if id == 'start' then
        return self.preset_setter_start[track][b][p]
    elseif id == 'end' then
        return self.preset_setter_end[track][b][p]
    end
end
function windowparams:get_base(id, t)
end
function windowparams:get(id, track, units, abs)
    units = units or 'fraction'

    if id == 'start' then
        return reg.play:get_start(track, units, abs)
    elseif id == 'end' then
        return reg.play:get_end(track, units, abs)
    elseif id == 'length' then
        return reg.play:get_length(track, units)
    end
end

local cs_mappabe_win = cs.def{ min = 0, max = 1, default = 0 }
local cs_mappabe_len = cs.def{ min = -1, max = 0, default = 0 }
local cs_base_win = cs.def{ min = -1, max = 1, default = 0 }
local cs_base_len = cs.def{ min = -1, max = 1, default = 0 }
local cs_preset_st = cs.def{ min = 0, max = 1, default = 0 }
local cs_preset_en = cs.def{ min = 0, max = 1, default = 1 }

function windowparams:base_params_count() return 2 * tracks * buffers end
function windowparams:add_base_params()
    for t = 1, tracks do
        for b = 1,buffers do
            params:add {
                id = self.base_id[t][b].win,
                type = 'control', controlspec = cs_base_win,
                action = function() self:bang(t) end
            }
            params:add {
                id = self.base_id[t][b].len,
                type = 'control', controlspec = cs_base_len,
                action = function() self:bang(t) end
            }
        end
    end
end
function windowparams:preset_params_count() return 2 * tracks * buffers * presets end
function windowparams:add_preset_params()
    for t = 1, tracks do
        for b = 1,buffers do
            for p = 1, presets do
                params:add{
                    id = self.preset_id[t][b][p].st,
                    type = 'control', controlspec = cs_preset_st,
                    action = function() self:bang(t) end
                }
                params:add{
                    id = self.preset_id[t][b][p].en,
                    type = 'control', controlspec = cs_preset_en,
                    action = function() self:bang(t) end
                }
            end
        end
    end
end
function windowparams:mappable_params_count() return 2 end
function windowparams:add_mappable_params(t)
    params:add {
        id = self.mappable_id[t].win, name = 'window',
        type = 'control', controlspec = cs_mappabe_win,
        action = function(v)
            for b = 1,buffers do
                params:set(self.base_id[t][b].win, v)
            end
        end
    }
    params:add {
        id = self.mappable_id[t].len, name = 'length',
        type = 'control', controlspec = cs_mappabe_len,
        action = function(v)
            for b = 1,buffers do
                params:set(self.base_id[t][b].en, v)
            end
        end
    }
end

return windowparams
