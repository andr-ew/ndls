-- softcut utilities

-- this is an intermediate data structure. any part of the program may read these values, but they should be set only from the params system or by functions in this file. the associated update function should be called after any value change.

local sc

sc = {
    phase = {
        { rel = 0, abs = 0, delta = 0, last = 0 },
        set = function(s, n, v)
            s[n].abs = v
            s[n].rel = reg.rec:phase_relative(n, v, 'fraction')
            s[n].delta = v - s[n].last

            crops.dirty.grid = true
            crops.dirty.arc = true
            crops.dirty.screen = true
            
            s[n].last = v
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
        { old = 1, rec = 0 },
        update = function(s, n)
            sc.send('rec_level', n, s[n].rec)
            sc.send('pre_level', n, (s[n].rec == 0) and 1 or (s[n].old))
            sc.sendmx[n].old = s[n].old
        end
    },
    panmx = {
        { pan = 0 },
        update = function(s, n) softcut.pan(n, util.clamp(s[n].pan, -1, 1)) end
    },
    ratemx = {
        { oct = 1, bnd = 0, dir = 1, rate = 1, recording = false },
        update = function(s, n)
            local dir = s[n].recording and math.abs(s[n].dir) or s[n].dir

            s[n].rate = 2^s[n].oct * 2^(s[n].bnd) * dir
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
    },
    loopmx = {
        { loop = 1 },
        update = function(s, n)
            softcut.loop(n, s[n].loop)
            if s[n].loop > 0 then
                --sc.trigger(n)
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
        --softcut.loop(i, 1)
        softcut.level_slew_time(i, sc.lvl_slew)
        --softcut.recpre_slew_time(i, 1)
        softcut.rate(i, 1)
        softcut.post_filter_dry(i, 0)
        softcut.pre_filter_fc_mod(i, 0)

        --softcut.level_input_cut(1, i, 1)
        --softcut.level_input_cut(2, i, 1)

        sc.slew(i, 0.2)

        --softcut.phase_quant(i, 1/100)
    end

    -- softcut.event_position(function(i, ph)
    --     if i <= ndls.voices then
    --         sc.phase:set(i, ph)
    --     end
    -- end)
    -- softcut.event_phase(function(i, ph)
    --     if i <= voices then
    --         sc.phase:set(i, ph)
    --     end
    -- end)
    -- softcut.poll_start_phase()

    softcut.event_position(function(i, ph)
        if i <= voices then
            sc.phase:set(i, ph)
        end
    end)
    clock.run(function() while true do for i = 1,4 do
        softcut.query_position(i)
        clock.sleep(1/90/2) -- 2x fps of arc
    end end end)
end

do
    local pfx = 'ndls_buffer_'

    sc.write = function(slot)
        local name = 'pset-'..string.format("%02d", slot)
        local dir = _path.audio..'ndls/'..name..'/'

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
    sc.read = function(slot)
        for i = 1, voices do
            params:set('rec '..i, 0) 
        end
        for b = 1,buffers do
            sc.punch_in:clear(b)
        end

        local name = 'pset-'..string.format("%02d", slot)
        local dir = _path.audio..'ndls/'..name..'/'

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
            end

            for b = 1, buffers do
                preset:update(i, b)
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

sc.trigger = function(n)
    -- local st = get_start(n, 'seconds', 'absolute')
    -- local en = get_end(n, 'seconds', 'absolute')
    local st = wparams:get('start', n, 'seconds', 'absolute')
    local en = wparams:get('end', n, 'seconds', 'absolute')
    softcut.position(n, sc.ratemx[n].rate > 0 and st or en)
end


--FIXME: punch-in with rate < 0 results in blank buffer
--TODO: manual initialization (via "end" controls)
--FIXME: intital recording at very low rates (?)
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
    update_recording = function(s, z)
        for n,v in ipairs(sc.buffer) do if v == z then
            sc.ratemx[n].recording = s[z].recording
            sc.ratemx:update(n)
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

            s:update_recording(buf)
        end
    end,
    is_recorded = function(s, track)
        local b = sc.buffer[track]
        return s[b].recorded
    end,
    is_recording = function(s, track)
        local b = sc.buffer[track]
        return s[b].recording
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
            s[buf].recording = false; s:update_recording(buf)
        end
    end,
    clear = function(s, z)
        local buf = z

        s[buf].play = 0; s:update_play(buf)
        reg.blank[buf]:clear()
        reg.rec[buf]:position(0)
        reg.rec[buf]:punch_out()


        s[buf].recorded = false
        s[buf].recording = false; s:update_recording(buf)
        s[buf].manual = false
        --s:untap(pair)

        --reg.rec[buf]:set_length(1, 'fraction')
        reg.rec[buf]:expand(1, 'fraction')

        --reg.play[buf]:set_length(0)
        --reg.zoom[buf]:set_length(0)
    end,
    was_loaded = function(s, b)
        s[b].recorded = true
        s[buf].recording = false; s:update_recording(buf)
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

local function update_assignment(n)
    local b = sc.buffer[n]
    local sl = reg.play[b][n]
    cartographer.assign(sl, n)
    
    sc.punch_in:update_play(b)

    -- if not dont_update_reg then
    --     wparams:bang(n)
    -- end
end

sc.buffer = { --[voice] = buffer
    --TODO: depricate
    set = function(s, n, v) params:set('buffer '..n, v) end,
    update = function(s, n)
        mparams:bang(n)
        update_assignment(n)
        wparams:bang(n)
    end
}

--TODO: depricate
sc.slice = preset

for n = 1,voices do
    sc.buffer[n] = n

    sc.slice[n] = {}
    for b = 1,buffers do
        sc.slice[n][b] = 1
    end

    update_assignment(n)
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
            crops.dirty.screen = true
        end)
        
        for i = 1,buffers do 
            s:render(i)
        end
    end
} 

return sc, reg
