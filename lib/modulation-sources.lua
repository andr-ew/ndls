local src = {}

do
    src.crow = {}

    local streams = {}
    for i = 1,2 do
        streams[i] = patcher.add_source('crow in '..i, 0)
    end
    -- src.crow.streams = streams

    -- src: https://github.com/monome/norns/blob/e8ae36069937df037e1893101e73bbdba2d8a3db/lua/core/crow.lua#L14
    local function re_enable_clock_source_crow()
        if params.lookup["clock_source"] then
            if params:string("clock_source") == "crow" then
                norns.crow.clock_enable()
            end
        end
    end

    function src.crow.update()
        local mapped = { false, false }

        for i = 1,2 do
            if #patcher.get_assignments_source('crow in '..i) > 0 then mapped[i] = true end
        end
        
        for i, map in ipairs(mapped) do if map then
            crow.input[i].mode('stream', 0.01)
            crow.input[i].stream = streams[i] 
        end end
        if not mapped[1] then re_enable_clock_source_crow() end
    end
    src.crow.update()

    norns.crow.add = src.crow.update
end

do
    src.lfos = {}
    
    for i = 1,2 do
        local action = patcher.add_source('lfo '..i, 0)

        src.lfos[i] = lfos:add{
            min = -5,
            max = 5,
            depth = 0.1,
            mode = 'free',
            period = 0.25,
            baseline = 'center',
            action = action,
        }
    end

    src.lfos.reset_params = function()
        for i = 1,2 do
            params:set('lfo_mode_lfo_'..i, 2)
            -- params:set('lfo_max_lfo_'..i, 5)
            -- params:set('lfo_min_lfo_'..i, -5)
            params:set('lfo_baseline_lfo_'..i, 2)
            params:set('lfo_lfo_'..i, 2)
        end
    end
end

do
    patcher.add_source('midi')

    -- local middle_c = 60

    -- local m = midi.connect()
    -- m.event = function(data)
    --     local msg = midi.to_msg(data)

    --     if msg.type == "note_on" then
    --         local note = msg.note
    --         local volt = (note - middle_c)/12

    --         patcher.set_source('midi', volt)
    --     end
    -- end

    -- src.midi = m
end

return src
