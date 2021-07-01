local voices, zones = ndls.voices, ndls.zones

-- softcut utilities
local sc = {
    phase = {
        { rel = 0, abs = 0 },
        set = function(s, n, v)
            s[n].abs = v
            s[n].rel = reg.rec:phase_relative(n, v, 'fraction')
        end
    },
    sendmx = {
        { vol = 1, old = 1, send = 1, ret = 0 },
        update = function(s)
            for dst = 1, voices do
                for src = 1,voices do if src ~= dst then
                    softcut.level_cut_cut(
                        src, dst, 
                          s[src].vol  * s[dst].old 
                        * s[src].send * s[dst].ret
                    )
                end end
            end
        end
    },
    lvlmx = {
        { vol = 1, play = 0, recorded = 0, send = 1 },         
        update = function(s, n)
            local v = s[n].vol * s[n].play * s[n].recorded
            softcut.level(n, v)
            sc.sendmx[n].vol = v
        end
    },
    oldmx = {
        { old = 1, rec = 0 },
        update = function(s, n)
            sc.send('rec_level', n, s[n].rec)
            sc.send('pre_level', n, (s[n].rec == 0) and 1 or s[n].old)
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
            end
    },
    inmx = { 
        { 1, 1 }, --lvl L, lvl R
        update = function(s, n)
            for i = 1,2 do softcut.level_input_cut(i, n, s[n][i]) end
        end
    },
    aliasmx = {
        { alias = 0, aliasing = 1 },
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
reg.blank = cartographer.divide(cartographer.buffer[1], zones)
reg.rec = cartographer.subloop(reg.blank)
reg.play = cartographer.subloop(reg.rec)

sc.setup = function()
    audio.level_cut(1)
    audio.level_adc_cut(1)

    --TODO input from single channel
    for i = 1, voices do
        softcut.enable(i, 1)
        softcut.rec(i, 1)
        softcut.play(i, 1)
        softcut.loop(i, 1)
        softcut.level_slew_time(i, 0.1)
        softcut.recpre_slew_time(i, 0.1)
        softcut.rate(i, 1)
        softcut.post_filter_dry(i, 0)
        
        softcut.level_input_cut(1, i, 1)
        softcut.level_input_cut(2, i, 1)
        
        sc.slew(i, 0.2)
        
        --adjust punch_in time quantum based on rate
        -- reg.rec[i].rate_callback = function() 
        --     return sc.ratemx[i].rate
        -- end
        softcut.phase_quant(i, 1/100)
    end

    -- softcut.event_position(function(i, ph)
    --     if i <= ndls.voices then
    --         sc.phase:set(i, ph) 
    --     end
    -- end)
    softcut.event_phase(function(i, ph)
        if i <= ndls.voices then
            sc.phase:set(i, ph) 
        end
    end)
    softcut.poll_start_phase()
end

-- scoot = function()
--     reg.play:position(2, 0)
--     reg.play:position(4, 0)
-- end,

--more utilities

sc.send = function(command, ...)
    softcut[command](...)
end

--TODO slewmx (tape/disk)
sc.slew = function(n, t)
    local st = (2 + (math.random() * 0.5)) * (t or 0)
    sc.send('rate_slew_time', n, st)
    return st
end

sc.fade = function(n, length)
    sc.send('fade_time', n, math.min(0.01, length))
end

sc.zone = {
    1, 2, 3, 4, --[voice] = zone
    update = function(s, n)
        cartographer.assign(reg.play[s[n]], n) --TODO don't reassign if zone matches
        sc.punch_in:update_play(s[n])
    end
}
        
sc.punch_in = {
    --indexed by zone
    { recording = false, recorded = false, manual = false, play = 0, t = 0, tap_blink = 0, tap_clock = nil, tap_buf = {}, big = false },
    update_play = function(s, z)
        for n,v in ipairs(sc.zone) do if v == z then 
            sc.lvlmx[n].recorded = s[z].play
            sc.lvlmx:update(n)
        end end
    end,
    -- big = function(s, z, v)
    --     local buf = z
    --     if v > 0.2 then s[buf].big = true end
    -- end,
    set = function(s, z, v)
        --TODO minimum length for rec zone
        local buf = z
        if not s[buf].recorded then
            if v == 1 then
                --reg.blank[buf]:set_length(16777216 / 48000 / 2) --wrong
                reg.rec[buf]:punch_in()

                --sc.oldmx[buf].rec = 1; sc.oldmx:update(buf)

                s[buf].manual = false
                s[buf].recording = true

            elseif s[buf].recording then
                --sc.oldmx[buf].rec = 0; sc.oldmx:update(buf)
                s[buf].play = 1; s:update_play(buf)
            
                reg.rec[buf]:punch_out()

                s[buf].recorded = true
                s[buf].big = true
                s[buf].recording = false
            end
        end
    end,
    get = function(s, z)
        return s[z].recording and 1 or 0
    end,
    manual = function(s, z)
        local buf = z

        --TODO caller sets mparam.rec high
        if not s[buf].recorded then
            --reg.blank[buf]:set_length(s.delay_size)
            reg.rec[buf]:set_length(1, 'fraction')
            
            s[buf].manual = true

            --sc.oldmx[buf].rec = 1; sc.oldmx:update(buf)
            s[buf].play = 1; s:update_play(buf)

            s[buf].recorded = true
        end
    end,
    untap = function(s, z)
        local buf = z

        s[buf].tap_buf = {}
        if s[buf].tap_clock then clock.cancel(s[buf].tap_clock) end
        s[buf].tap_clock = nil
        s[buf].tap_blink = 0
    end,
    tap = function(s, z, t)
        local buf = z

        if t < 1 and t > 0 then
            table.insert(s[buf].tap_buf, t)
            if #s[buf].tap_buf > 2 then table.remove(s[buf].tap_buf, 1) end
            local avg = 0
            for i,v in ipairs(s[buf].tap_buf) do avg = avg + v end
            avg = avg / #s[buf].tap_buf

            reg.play:set_length(n*2, avg)
            sc.punch_in:big(n, avg)

            if s[buf].tap_clock then clock.cancel(s[buf].tap_clock) end
            s[buf].tap_clock = clock.run(function() 
                while true do
                    s[buf].tap_blink = 1
                    clock.sleep(avg*0.5)
                    s[buf].tap_blink = 0
                    clock.sleep(avg*0.5)
                end
            end)
        else s:untap(z) end
    end,
    clear = function(s, z)
        local buf = z
        local i = buf

        s[buf].play = 0; s:update_play(buf)
        reg.rec[buf]:position(0)
        reg.rec[buf]:clear()
        reg.rec[buf]:punch_out()


        s[buf].recorded = false
        s[buf].recording = false
        s[buf].big = false
        s[buf].manual = false
        s:untap(z)

        reg.rec[buf]:set_length(1, 'fraction')
        reg.play[buf]:set_length(0)
    end,
    save = function(s)
        local data = {}
        for i,v in ipairs(s) do data[i] = s[i].manual end
        return data
    end,
    load = function(s, data)
        for i,v in ipairs(data) do
            s[i].manual = v
            if v==true then 
                s:manual(i)
                s:big(i, reg.play[1][1]:get_length())
            else 
                --s:clear(i) 
                if sc.buf[i]==i then params:delta('clear '..i) end
            end
        end
    end,
    copy = function(s, src, dst)
    end
}

--punch_in shallow copy first index for each zone
for i = 2, zones do
    sc.punch_in[i] = {}
    for l,v in pairs(sc.punch_in[1]) do
        sc.punch_in[i][l] = v
    end
end

return sc, reg
