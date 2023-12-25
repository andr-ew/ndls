-- softcut utilities

-- this is an intermediate data structure. any part of the program may read these values, but they should be set only from the params system or by functions in this file. the associated update function should be called after any value change.

local sc

local function ampdb(amp) return math.log10(amp) * 20.0 end
local function dbamp(db) return math.pow(10.0, db*0.05) end

local buf_time = 16777216 / 48000 --exact time from the sofctcut source

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
        { 
            lvl = 0.987654321, gain = 0.987654321, 
            amp = 1, db = 0, play = 0, recorded = 0, send = 1 
        },
        update = function(s, n)
            s[n].amp = s[n].lvl * s[n].gain
            s[n].db = ampdb(s[n].amp)
            local out = s[n].amp * s[n].play * s[n].recorded

            sc.send('level', n, out)
            sc.sendmx[n].vol = out; sc.sendmx:update(n)
        end
    },
    oldmx = {
        { old = 0.987654321, rec = 0 },
        update = function(s, n)
            sc.send('rec_level', n, s[n].rec)
            sc.send('pre_level', n, (s[n].rec == 0) and 1 or (s[n].old))
            sc.sendmx[n].old = s[n].old
        end
    },
    sprmx = {
        { 
            spr = 0.0000000001001,  -- i promise i did this for a reason please please beleive me
            pan = 0 
        },
        scale = { 1, -0.75, 0.5, -0.25, 0.75, -1 },
        update = function(s, n) 
            s[n].pan = util.clamp(s[n].spr * s.scale[n], -1, 1)
            softcut.pan(n, s[n].pan)
        end
    },
    ratemx = {
        { oct = 0, bnd = 1.000000000001893790, dir = 1, rate = 1, recording = false },
        update = function(s, n)
            local dir = s[n].recording and math.abs(s[n].dir) or s[n].dir

            s[n].rate = 2^s[n].oct * (s[n].bnd) * dir
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
                sc.send('pre_filter_dry', n, 1)
                sc.send('pre_filter_lp', n, 0)
            else
                sc.send('pre_filter_dry', n, 0)
                sc.send('pre_filter_lp', n, 1)
            end
        end
    },
    loopmx = {
        { loop = nil },
        update = function(s, n)
            sc.send('loop', n, s[n].loop or 1)
            if s[n].loop > 0 then
                sc.trigger(n)
            end
        end
    },
    -- filtermx = {
    --     { fc = nil, rq = nil, typ = nil }
    -- },
    slewmx = {
        { slew = nil },
    }
}

sc.filtermx = {
    { 
        qual = -0.99999989, cut = 0.99999989, crv = -0.999999999879, 
        lp = 0, bp = 0, hp = 0, dry = 0, q = 0 
    },
    update = function(s, n)
        local wet = 1

        if s[n].qual < 0 then 
            s[n].dry = -1 * s[n].qual
            wet = 1 + s[n].qual 
            s[n].q = 0
        else
            s[n].dry = 0
            s[n].q = s[n].qual
        end

        if s[n].crv <= 0 then
            s[n].lp = (-1 * s[n].crv) * wet
            s[n].bp = (1 + s[n].crv) * wet
            s[n].hp = 0
        else
            s[n].lp = 0
            s[n].bp = (1 - s[n].crv) * wet
            s[n].hp = s[n].crv * wet
        end

        softcut.post_filter_rq(n, util.linexp(0, 1, 0.01, 20, 1 - s[n].q))
        softcut.post_filter_dry(n, s[n].dry)
        softcut.post_filter_lp(n, s[n].lp)
        softcut.post_filter_bp(n, s[n].bp)
        softcut.post_filter_hp(n, s[n].hp)

        filtergraphs[n].dirty = true
    end
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

sc.reset_slices = function()
    reg.blank = cartographer.divide(cartographer.buffer, buffers)
    reg.rec = cartographer.subloop(reg.blank)
    reg.play = cartographer.subloop(reg.rec, voices)
end
sc.reset_slices()


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
        sc.send('enable', i, 1)
        sc.send('rec', i, 1)
        sc.send('play', i, 1)
        --softcut.loop(i, 1)
        sc.send('level_slew_time', i, sc.lvl_slew)
        --softcut.recpre_slew_time(i, 1)
        sc.send('rate', i, 1)
        sc.send('post_filter_dry', i, 0)
        sc.send('pre_filter_fc_mod', i, 0)

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
    local ext = '.wav'

    sc.write = function(slot)
        local name = 'pset-'..string.format("%02d", slot)
        local dir = _path.audio..'ndls/'..name..'/'

        if not util.file_exists(dir) then
            util.make_dir(dir)
        end

        for b = 1,buffers do
            local f = dir..pfx..b..ext

            if sc.punch_in[b].recorded then
                reg.rec[b]:write(f)
                print('sc write '..f)
            else
                print('sc deleting if exists '..f)
                norns.system_cmd("rm "..f)
            end
        end
    end
    sc.read = function(slot)
        -- for i = 1, voices do
        --     params:set('rec '..i, 0) 
        -- end
        for b = 1,buffers do
            sc.punch_in:clear(b)
        end

        local name = 'pset-'..string.format("%02d", slot)
        local dir = _path.audio..'ndls/'..name..'/'

        local files_to_load = {}

        for b = 1,buffers do
            files_to_load[b] = { buf = b, file_length = 0 }

            local f = dir..pfx..b..ext
            if util.file_exists(f) then
                local ch, samples, rate = audio.file_info(f)
                if samples then files_to_load[b].file_length = (samples/rate) end
            end
        end
        table.sort(files_to_load, function(a, b) 
            return a.file_length > b.file_length
        end)

        local did_load = {}
        for _,to_load in ipairs(files_to_load) do
            local b = to_load.buf
            did_load[b] = sc.loadsample(b, dir..pfx..b..ext)
        end
        for i = 1, voices do
            if not did_load[sc.buffer[i]] then
                params:set('rec '..i, 0)
            end
            for b = 1, buffers do
                preset:update(i, b)
            end
        end
    end
    sc.delete = function(slot)
        local name = 'pset-'..string.format("%02d", slot)
        local dir = _path.audio..'ndls/'..name..'/'
        
        for b = 1,buffers do
            local f = dir..pfx..b..ext
            if util.file_exists(f) then
                print('deleting if exists '..f)
                norns.system_cmd("rm "..f)
            end
        end
    end
end

--sometimes a lookup table is easier than an algorithm :)
local adjacent_slice_info = { -- [my_idx] = {}
    { adj_idx = 2, my_edge = 'end', adj_edge = 'start', direction = 1 },
    { adj_idx = 1, my_edge = 'start', adj_edge = 'end', direction = -1 },
    { adj_idx = 4, my_edge = 'end', adj_edge = 'start', direction = 1 },
    { adj_idx = 3, my_edge = 'start', adj_edge = 'end', direction = -1 },
}

sc.buffer_is_expandable = function(buffer)
    local my_idx = buffer
    local info = adjacent_slice_info[my_idx]
    local adj_idx = info.adj_idx
    local adj_is_recorded = sc.punch_in[adj_idx].recorded

    return (not tall) and (not adj_is_recorded)
end

-- call params:delta('clear') before calling
-- call params:set('play '..n, 1) after calling
sc.loadsample = function(buffer, path)
    local b, f = buffer, path

    if util.file_exists(f) then
        --expand blank slice if possible & needed
        --TODO: make this work for 256 grids
        if not tall then
            local ch, samples, rate = audio.file_info(f)
            local silent = true
            if samples then
                local file_len = (samples/rate)
                if file_len > buf_time then file_len = buf_time end

                local my_idx = b
                local my_slice = reg.blank[my_idx]
                local my_len = my_slice:get_length('seconds')

                local info = adjacent_slice_info[my_idx]

                local adj_idx = info.adj_idx
                local adj_slice = reg.blank[adj_idx]
                local adj_is_recorded = sc.punch_in[adj_idx].recorded

                if (file_len > my_len) and (not adj_is_recorded) then
                    local len_diff = file_len - my_len

                    my_slice['delta_'..info.my_edge](
                        my_slice, len_diff * info.direction, 'seconds'
                    )
                    my_slice:expand_children(silent)
                    adj_slice['delta_'..info.adj_edge](
                        adj_slice, len_diff * info.direction, 'seconds'
                    )

                    print(
                        'buffer '..b..': expanded slice to '..file_len..'s'
                    )
                end
            else
                print("ndls: couldn't load file info for "..file.." ...may truncate")
            end
        end

        --read sample into slice
        reg.rec[b]:read(f, nil, nil, 'source')
        sc.punch_in:was_loaded(b)

        print('buffer '..b..': loaded sample '..f)

        return true
    end
end

sc.exportsample = function(track, name)
    if sc.punch_in:is_recorded(track) then
        local dir = _path.audio..'ndls/export_'..os.date('%d-%b-%Y')..'/'
        if not util.file_exists(dir) then
            util.make_dir(dir)
        end

        local f = dir..name..'.wav'

        reg.play:write(track, f)
        print('track '..track..': exported sample '..f)
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
    local st = reg.play:get_start(n, 'seconds', 'absolute')
    local en = reg.play:get_end(n, 'seconds', 'absolute')
    sc.send('position', n, sc.ratemx[n].rate > 0 and st or en)
end

--FIXME: intital recording at very low rates (?)
sc.punch_in = { -- [buf] = {}
    { 
        recording = false, recorded = false, play = 0, t = 0,
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
    set = function(s, buf, v)

        if not s[buf].recorded then
            if v == 1 then
                reg.rec[buf]:punch_in()

                s[buf].recording = true

            elseif s[buf].recording then
                s[buf].play = 1; s:update_play(buf)
            
                reg.rec[buf]:punch_out()

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
    get = function(s, buf)
        return s[buf].recording and 1 or 0
    end,
    clear = function(s, buf)
        s[buf].play = 0; s:update_play(buf)
        reg.blank[buf]:clear()
        reg.rec[buf]:position(0)
        reg.rec[buf]:punch_out()


        s[buf].recorded = false
        s[buf].recording = false; s:update_recording(buf)

        reg.rec[buf]:expand(1, 'fraction')
    end,
    was_loaded = function(s, b)
        s[b].recorded = true
        s[b].recording = false; s:update_recording(b)
        
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

sc.buf_time = buf_time

return sc, reg
