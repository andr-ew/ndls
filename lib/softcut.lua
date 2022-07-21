-- softcut utilities

-- this is an intermediate data structre. any part of the program may read these values, but they should be set only from the params system or by functions in this file. the associated update function should be called after any value change (exceptions where noted).

local sc

sc = {
    phase = {
        { rel = 0, abs = 0 },
        set = function(s, n, v)
            s[n].abs = v
            s[n].rel = reg.rec:phase_relative(n, v, 'fraction')

            nest.grid.make_dirty()
            nest.arc.make_dirty()
            nest.screen.make_dirty()
        end
    },
    inmx = {
        {},
        route = 'left',
        update = function(s, n)
            if s.route == 'left' then
                softcut.level_input_cut(1, n, 1)
                softcut.level_input_cut(2, n, 0)
            elseif s.route == 'right' then
                softcut.level_input_cut(1, n, 0)
                softcut.level_input_cut(2, n, 1)
            end
        end
    },
    sendmx = {
        { vol = 1, old = 1, send = 0, ret = 1 },
        update = function(s)
            for dst = 1, voices do
                for src = 1,voices do if src ~= dst then
                    softcut.level_cut_cut(
                        src, dst,
                        s[src].vol  * s[dst].old * s[src].send * s[dst].ret
                    )
                end end
            end
        end
    },
    lvlmx = {
        { vol = 1, play = 0, recorded = 0, send = 1, cf_assign = 1, mix_vol = 1 },
        cf = 0,
        update = function(s, n)
            local v = s[n].vol * s[n].play * s[n].recorded
            local fades = {
                [0] = 1,
                [1] = (s.cf > 0) and (1 - s.cf) or 1,
                [2] = (s.cf < 0) and (1 + s.cf) or 1
            }

            softcut.level(n, v * fades[s[n].cf_assign] * s[n].mix_vol)
            sc.sendmx[n].vol = v; sc.sendmx:update(n)
        end
    },
    oldmx = {
        { old = 1, old2 = 1, rec = 0 },
        update = function(s, n)
            sc.send('rec_level', n, s[n].rec)
            sc.send('pre_level', n, (s[n].rec == 0) and 1 or (s[n].old * s[n].old2))
            sc.sendmx[n].old = s[n].old
        end
    },
    panmx = {
        { pan = 0 },
        update = function(s, n) softcut.pan(n, util.clamp(s[n].pan, -1, 1)) end
    },
    ratemx = {
            { oct = 1, bnd = 0, dir = 1, rate = 1 },
            update = function(s, n)
                s[n].rate = 2^s[n].oct * 2^(s[n].bnd) * s[n].dir
                sc.send('rate', n, s[n].rate)
                --set phase_quant to a constant when rate < 1
            end
    },
    --[[
    inmx = {
        { 1, 1 }, --lvl L, lvl R
        update = function(s, n)
            for i = 1,2 do softcut.level_input_cut(i, n, s[n][i]) end
        end
    },
    ]]--
    aliasmx = {
        { alias = 0 },
        update = function(s, n)
            if s[n].alias == 1 then
                softcut.pre_filter_dry(n, 1)
                softcut.pre_filter_lp(n, 0)
            else
                softcut.pre_filter_dry(n, 0)
                softcut.pre_filter_lp(n, 1)
            end
        end
    }
}

--shallow copy first index for each voice for objects above
for k,o in pairs(sc) do
    for i = 2, voices do
        o[i] = {}
        for l,v in pairs(o[1]) do
            o[i][l] = v
        end
    end
end

--softcut buffer regions
local reg = {}
reg.blank = cartographer.divide(cartographer.buffer[1], buffers)
reg.rec = cartographer.subloop(reg.blank)
reg.play = cartographer.subloop(reg.rec, voices)

for b = 1, buffers do
    --adjust punch_in time quantum based on rate
    reg.rec[b].rate_callback = function()
        local voice
        for vc = 1,voices do if sc.buffer[vc] == b then
            if voice then
                if sc.punch_in[b].recording then voice = vc end
            else
                voice = vc
            end
        end end
        return voice and sc.ratemx[voice].rate or 1
    end
end

sc.lvl_slew = 0.1
sc.init = function()
    audio.level_cut(1)
    audio.level_adc_cut(1)

    for i = 1, voices do
        softcut.enable(i, 1)
        softcut.rec(i, 1)
        softcut.play(i, 1)
        softcut.loop(i, 1)
        softcut.level_slew_time(i, sc.lvl_slew)
        --softcut.recpre_slew_time(i, 1)
        softcut.rate(i, 1)
        softcut.post_filter_dry(i, 0)
        softcut.pre_filter_fc_mod(i, 0)

        --softcut.level_input_cut(1, i, 1)
        --softcut.level_input_cut(2, i, 1)

        sc.slew(i, 0.2)

        softcut.phase_quant(i, 1/100)
    end

    -- softcut.event_position(function(i, ph)
    --     if i <= ndls.voices then
    --         sc.phase:set(i, ph)
    --     end
    -- end)
    softcut.event_phase(function(i, ph)
        if i <= voices then
            sc.phase:set(i, ph)
        end
    end)
    softcut.poll_start_phase()
end

do
    --TODO: read & write based on pset #, call on params.action_read/action_write

    local pfx = 'ndls_buffer_'

    sc.write = function()
        local dir = norns.state.path..'audio/ndls/ndls/'

        if not util.file_exists(dir) then
            util.make_dir(dir)
        end

        for b = 1,buffers do
            if sc.punch_in[b].recorded then
                local f = dir..pfx..b
                reg.rec[b]:write(f)
                print('write '..f)
            end
        end
    end
    sc.read = function()
        local dir = norns.state.path..'audio/ndls/ndls/'

        local loaded = {}
        for b = 1,buffers do
            local f = dir..pfx..b
            if util.file_exists(f) then
                reg.rec[b]:read(f, nil, nil, 'source')
                loaded[b] = true
                sc.punch_in:was_loaded(b)
                print('read '..f)
            end
        end
        for i = 1, voices do
            if not loaded[sc.buffer[i]] then
                params:set('rec '..i, 0)
                params:set('play '..i, 0)
            end
        end
    end
end

sc.send = function(command, ...)
    softcut[command](...)
end

sc.slew = function(n, t)
    local st = (2 + (math.random() * 0.5)) * (t or 0)
    sc.send('rate_slew_time', n, util.clamp(0, 2.5, st))
    return st
end

sc.fade = function(n, length)
    sc.send('fade_time', n, math.min(0.01, length))
end


--FIXME: punch-in with rate < 0 results in blank buffer
--TODO: manual initialization (via "end" controls)
--FIXME: intital recording at very low rates (?)
--FIXME: intial recording in non-default buffer clears default buffer (?)
sc.punch_in = { -- [buf] = {}
    min_size = 0.5,
    { 
        recording = false, recorded = false, manual = false, play = 0, t = 0,
    },
    update_play = function(s, z)
        for n,v in ipairs(sc.buffer) do if v == z then
            sc.lvlmx[n].recorded = s[z].play
            sc.lvlmx:update(n)
        end end
    end,
    set = function(s, z, v)
        local buf = z

        if not s[buf].recorded then
            if v == 1 then
                reg.rec[buf]:punch_in()

                s[buf].manual = false
                s[buf].recording = true

            elseif s[buf].recording then
                s[buf].play = 1; s:update_play(buf)
            
                reg.rec[buf]:punch_out()
                --TODO: if len < min_size then len = min_size

                s[buf].recorded = true
                s[buf].recording = false
            end
        end
    end,
    get = function(s, z)
        return s[z].recording and 1 or 0
    end,
    --NOTE: set these when calling manual:
    -- params:set('rec '..n, 1)
    -- params:set('play '..n, 1)
    manual = function(s, z)
        local buf = z

        if not s[buf].recorded and not s[buf].recording then
            reg.rec[buf]:set_length(s.min_size)
            
            s[buf].manual = true
            s[buf].recorded = true
            s[buf].recording = false
        end
    end,
    clear = function(s, z)
        local buf = z

        s[buf].play = 0; s:update_play(buf)
        reg.blank[buf]:clear()
        reg.rec[buf]:position(0)
        reg.rec[buf]:punch_out()


        s[buf].recorded = false
        s[buf].recording = false
        s[buf].manual = false
        --s:untap(pair)

        --reg.rec[buf]:set_length(1, 'fraction')
        reg.rec[buf]:expand(1, 'fraction')

        --reg.play[buf]:set_length(0)
        --reg.zoom[buf]:set_length(0)
    end,
    was_loaded = function(s, b)
        s[b].recorded = true
        s[b].recording = false
        s[b].manual = false
        
        s[b].play = 1; s:update_play(b)
    end
}

--punch_in shallow copy first index for each zone
for i = 2, buffers do
    sc.punch_in[i] = {}
    for l,v in pairs(sc.punch_in[1]) do
        sc.punch_in[i][l] = v
    end
end

local function update_assignment(n, dont_update_reg)
    local b = sc.buffer[n]
    local sl = reg.play[b][n]
    cartographer.assign(sl, n)
    
    sc.punch_in:update_play(b)

    if not dont_update_reg then
        for s = 1, slices do
            update_reg(n, b, s)
        end
    end
end

sc.buffer = { --[voice] = buffer
    --TODO: depricate
    set = function(s, n, v) params:set('buffer '..n, v) end,
    update = function(s, n)
        update_assignment(n)
    end
}
sc.slice = { --[voice][buffer] = slice
    --TODO: depricate
    set = function(s, n, b, v) params:set('slice '..n..' buffer '..b, v) end,
    update = function(s, n, b)
        if b == sc.buffer[n] then
            update_assignment(n)
        end
    end,
    expand = function(s, vc, sl)
        local b = sc.buffer[vc]
        local pfx = vc..' buffer '..b..' slice '..sl

        local silent = true
        params:set('start '..pfx, 0, silent)
        params:set('end '..pfx, 1, silent)
        update_reg(vc, b, sl)
    end,
    randomize = function(s, vc, sl, target)
        local b = sc.buffer[vc]
        local b_sl = reg.rec[b]
        --local p = reg.play[b]

        local pfx = vc..' buffer '..b..' slice '..sl

        local available = b_sl:get_length()
        local last_s_f = params:get('start '..pfx)
        local last_e_f = params:get('end '..pfx)
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
            params:set('start '..pfx, st_f, silent)

            if not do_len then 
                --p:set_length(ll) 
                print(last_len_f)
                params:set('end '..pfx, st_f + last_len_f, silent)
            end
        end
        if do_len then 
            --p:set_length(len, 'seconds') 
            local sst_f = do_st and st_f or last_s_f
            params:set('end '..pfx, sst_f + len_f, silent)
        end

        update_reg(vc, b, sl)
    end,
    --call after loop punch_out
    --TODO: reset when entering recorded buffer for the first time
    reset = function(s, n)
        s:set(n, sc.buffer[n], 1)

        s:expand(n, 1)
        for sl = 2, slices do s:randomize(n, sl, 'both') end
    end,
    get = function(s, n)
        local b = sc.buffer[n]
        return s[n][b]
    end
}
for n = 1,voices do
    sc.buffer[n] = n

    sc.slice[n] = {}
    for b = 1,buffers do
        sc.slice[n][b] = 1
    end

    update_assignment(n, true)
end

sc.samples = { -- [buffer] = { samples }
    width = 0,
    render = function(s, buf)
        reg.rec[buf]:render(s.width)
    end,
    init = function(s, width)
        s.width = width

        local events = {}
        for i = 1,buffers do 
            s[i] = {} 

            events[i] = reg.rec[i]:event_render(function(interval, samps) 
                s[i] = samps 
            end)
        end

        softcut.event_render(function(...)
            for i,e in ipairs(events) do e(...) end
            nest.screen.make_dirty()
        end)
        
        for i = 1,buffers do 
            s:render(i)
        end
    end
} 

return sc, reg
