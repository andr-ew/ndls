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
                    ..'_track_'..t
                    ..'_base_'..b
                ),
                len = (
                    'length'
                    ..'_track_'..t
                    ..'_base_'..b
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
                        ..'_track_'..t
                        ..'_buffer_'..b
                        ..'_preset_'..p
                    ),
                    en = (
                        'end'
                        ..'_track_'..t
                        ..'_buffer_'..b
                        ..'_preset_'..p
                    )
                }
            end
        end
    end
    local set_start = {}
    local set_end = {}
    for t = 1, tracks do
        set_start[n] = {}
        set_end[n] = {}

        for b = 1, buffers do
            set_start[n][b] = {}
            set_end[n][b] = {}

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

    return m
end

function windowparams:bang(t)
    local b = sc.buffer[voice]
    local p = sc.slice:get(voice)

    --TODO: sum with base vals
    local st = params:get(m.preset_id[t][b][p].st)
    local en = params:get(m.preset_id[t][b][p].en)

    reg.play[b][t]:expand()
    reg.play[b][t]:set_start(st, 'fraction')
    reg.play[b][t]:set_end(en, 'fraction')

    nest.screen.make_dirty(); nest.arc.make_dirty()
end

local function expand(t, p)
    local vc = t
    local sl = p

    local b = sc.buffer[vc]
    local id_start = m.preset_id[t][b][p].st
    local id_end = m.preset_id[t][b][p].en

    local silent = true
    params:set(id_start, 0, silent)
    params:set(id_end, 1, silent)
end

local function randomize(t, p, target)
    local vc = t
    local sl = p

    local b = sc.buffer[vc]
    local b_sl = reg.rec[b]
    --local p = reg.play[b]

    local id_start = m.preset_id[t][b][p].st
    local id_end = m.preset_id[t][b][p].en

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

    local silent = true

    --if do_st then p:expand() end
    if do_st then 
        --p:set_start(st, 'seconds') 
        params:set(id_start, st_f, silent)

        if not do_len then 
            --p:set_length(ll) 
            params:set(id_end, st_f + last_len_f, silent)
        end
    end
    if do_len then 
        --p:set_length(len, 'seconds') 
        local sst_f = do_st and st_f or last_s_f
        params:set(id_end, sst_f + len_f, silent)
    end
end

function windowparams:reset(t)
    expand(t, 1)
    for p = 2, presets do randomize(t, p, 'both') end
end

function windowparams:set_base(id)
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
function windowparams:get_base(id)
end
function windowparams:get(id, track, units, abs)
    units = units or 'fraction'

    if id == 'start' then
        return reg.play:get_start(track, units, abs)
    elseif id == 'end' then
        return reg.play:get_end(track, units, abs)
    elseif id == 'len' then
        return reg.play:get_length(track, units)
    end
end

local cs_mappabe_win = cs.def{ min = 0, max = 1, default = 0 }
local cs_mappabe_len = cs.def{ min = -1, max = 0, default = 0 }
local cs_base_win = cs.def{ min = -1, max = 1, default = 0 }
local cs_base_len = cs.def{ min = -1, max = 1, default = 0 }
local cs_preset_st = cs.def{ min = 0, max = 1, default = 0 }
local cs_preset_en = cs.def{ min = 0, max = 1, default = 1 }

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
function windowparams:add_preset_params()
    for t = 1, tracks do
        for b = 1,buffers do
            for p = 1, presets do
                params:add {
                    id = self.preset_id[t][b][p].st,
                    type = 'control', controlspec = cs_preset_st,
                    action = function() self:bang(t) end
                }
                params:add {
                    id = self.preset_id[t][b][p].en,
                    type = 'control', controlspec = cs_preset_en,
                    action = function() self:bang(t) end
                }
            end
        end
    end
end
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
