local Components = {
    grid = {},
    arc = {},
    norns = {},
}

function Components.norns.slider(...)
    local x, y, width, height, value, min_value, max_value, markers, direction = ...

    local slider = UI.Slider.new(...)

    return function(props)
        if nest.enc.has_input() then
            local n, d = nest.enc.input_args()
            
            if n == props.n then
                props.state[2](
                    props.state[1] + (d * (props.sens or 0.01))
                )

                nest.screen.make_dirty()
            end
        elseif nest.screen.is_drawing() then
            slider:set_value(props.state[1])
            if props.markers then for id,position in pairs(props.markers) do
                slider:set_marker_position(id, position)
            end end
            if props.active ~= nil then slider:set_active(props.active) end
            
            slider:redraw()
        end
    end
end

function Components.norns.waveform(args)
    local left, right = args.x[1], args.x[2]
    local width = right - left + 1
    local top, bottom = args.y[1], args.y[2]
    local height = bottom - top + 1
    local equator = math.floor(top + height/2)
    local amp = math.floor(height/2)
    
    sc.samples:init(width)

    return function(props)
        local lvl = props.lvl or { window = 15, phase = 4, wave = 1 }
        local reg = props.reg
        local st, en = props.st, props.en
        local ph = props.phase
        local recording = props.recording
        local recorded = props.recorded
        local show_phase = props.show_phase
        local samples = props.samples
        local render = props.render or function() end
        --local rec_flag = props.rec_flag

        if not recorded then
            if recording then
                screen.level(lvl.window)
                screen.move(left + width * reg:get_start('fraction'), equator)
                screen.line(left + width * reg:get_end('fraction'), equator)
                screen.stroke()

                nest.screen.make_dirty()
            end
        else
            --waveform
            screen.level(lvl.wave)
            screen.move(left, equator)
            screen.line(right, equator)
            screen.stroke()
            for i = 1,width do
                local x = left + i
                local s = samples[i]
                if s then
                    local a = util.round(math.min(math.abs(s * 2), 1) * amp)
                    --local db = 20 * math.log(a, 10)
                    local db = a
                    screen.move(x, equator - db - 1)
                    screen.line_rel(0, 2 * db + 1)
                    screen.stroke()
                end
            end

            screen.level(lvl.window)
            --st
            screen.move(left + width * st, top)
            screen.line(left + width * st, bottom)
            screen.stroke()
            --en
            screen.move(left + width * en, top)
            screen.line(left + width * en, bottom)
            screen.stroke()
            --phase
            if show_phase then
                screen.level(lvl.phase)
                screen.move(left + width * ph, top)
                screen.line(left + width * ph, bottom)
                screen.stroke()
            end
            
            render()
            nest.screen.make_dirty()
        end
    end
end

function Components.grid.view()
    local held = {}

    return function(props)
        local tall = props.tall

        local g = nest.grid.device()

        local vertical = props.vertical[1]
        local set_vertical = props.vertical[2]

        if nest.grid.has_input() then
            local x, y, z = nest.grid.input_args()
            
            if
                x >= props.x and x <= props.x + (tall and 5 or 3) 
                    and y >= props.y and y <= props.y + (tall and 5 or 3)
            then
                local dx, dy = x - props.x + 1, y - props.y + 1

                if z == 1 then
                    table.insert(held, { x = dx, y = dy })

                    if not tall then
                        if #held > 1 then
                            if held[1].x == held[2].x then 
                                vertical = true
                                set_vertical(true)
                            elseif held[1].y == held[2].y then 
                                vertical = false
                                set_vertical(false) 
                            end
                        end
                    end

                    for i = 1,tall and 6 or 4 do --y
                        for j = 1,4 do --x 
                            props.view[i][j] = (
                                vertical and dx == j
                            )
                                and 1 
                                or ((not vertical and dy == i) and 1 or 0)
                        end 
                    end

                    props.action(vertical, dx, dy)
                    nest.grid.make_dirty()
                else
                    for i,v in ipairs(held) do
                        if v.x == dx and v.y == dy then table.remove(held, i) end
                    end
                end
            end
        elseif nest.grid.is_drawing() then
            for i = 0,tall and 5 or 3 do for j = 0,3 do 
                g:led(props.x + j, props.y + i, props.view[i + 1][j + 1] * props.lvl)
            end end
        end
    end
end

function Components.grid.phase()
    return function(props)
        local g = nest.grid.device()

        if nest.grid.is_drawing() then
            g:led(
                props.x[1] 
                    + math.floor(props.phase * (props.x[2] - props.x[1] + 1)), 
                props.y, 
                props.lvl
            )
        end
    end
end

function Components.grid.buffer64(args)
    local n = args.voice
    local x = args.x
    local y = args.y

    local truth_tab = {
        { 0, 0 },
        { 1, 0 },
        { 0, 1 },
        { 1, 1 }
    }
    local def = truth_tab[sc.buffer[n]]
    local cur = { def[1], def[2] }
    local function set_buf()
        local bv
        for i,truth in ipairs(truth_tab) do
            if cur[1] == truth[1] and cur[2] == truth[2] then
                bv = i
            end
        end
        sc.buffer:set(n, bv)

        nest.arc.make_dirty()
        nest.screen.make_dirty()
    end

    local _l = to.pattern(mpat, 'l buffer '..n, Grid.toggle, function()
        return {
            x = x[1], y = y,
            state = {
                cur[1],
                function(v)
                    cur[1] = v; set_buf()
                end
            }
        }
    end)
    local _r = to.pattern(mpat, 'r buffer '..n, Grid.toggle, function()
        return {
            x = x[2], y = y,
            state = {
                cur[2],
                function(v)
                    cur[2] = v; set_buf()
                end
            }
        }
    end)

    return function() _l(); _r() end
end

function Components.arc.filter()
    return function(props)
        local a = nest.arc.device()

        if nest.arc.is_drawing() then
            local v = props.cut
            local vv = math.floor(v*(props.x[2] - props.x[1])) + props.x[1]
            local t = props.type

            for x = props.x[1], props.x[2] do
                a:led(
                    props.n, 
                    (x - 1) % 64 + 1, 
                    t==1 and (               --lp
                        (x < vv) and 4
                        or (x == vv) and 15
                        or 0
                    )
                    or t==2 and (            --bp
                        util.clamp(
                            15 - math.abs(x - vv)*3,
                        0, 15)
                    )
                    or t==3 and (            --hp
                        (x < vv) and 0
                        or (x == vv) and 15
                        or 4
                    )
                    or t==4 and 4            --dry
                )
            end
        end
    end
end

function Components.arc.st(args)
    return function(props)
        local a = nest.arc.device()
        
        local recording = props.recording
        local recorded = props.recorded
        --local rec_flag = props.rec_flag
        local reg = props.reg
        local off = props.rotated and 16 or 0
        
        if nest.arc.has_input() then
            local n, d = nest.arc.input_args()
            
            if n == props.n then
                --props. 
                
                --local st, en = props.state[1].st, props.state[1].en
                local st = props.st[1]
                local en = props.en[1]
                props.st[2](props.st[1] + d * props.sens * 2)
                props.en[2](props.en[1] + d * props.sens * 2)

                nest.arc.make_dirty()
            end
        elseif nest.arc.is_drawing() then
            if not recorded then
                if recording then
                    local st = props.x[1]
                    local en = props.x[1] - 1 + math.ceil(
                        reg:get_end('fraction')*(props.x[2] - props.x[1] + 2)
                    )
                    for x = st,en do
                        a:led(props.n, (x - 1) % 64 + 1 - off, props.lvl[1])
                    end
                end
            else
                local st = props.x[1] + math.ceil(
                    props.st[1]*(props.x[2] - props.x[1] + 2)
                )
                local en = props.x[1] - 1 + math.ceil(
                    props.en[1]*(props.x[2] - props.x[1] + 2)
                )
                local ph = props.x[1] + util.round(
                    props.phase * (props.x[2] - props.x[1])
                )
                local show = props.show_phase
                for x = st,en do
                    a:led(props.n, (x - 1) % 64 + 1 - off, props.lvl[(x==ph and show) and 2 or 1])
                end
            end
        end
    end
end

function Components.arc.len(mpat)
    return function(props)
        local a = nest.arc.device()

        local recording = props.recording
        local recorded = props.recorded
        --local rec_flag = props.rec_flag
        local reg = props.reg
        local off = props.rotated and 16 or 0
        
        if nest.arc.has_input() then
            local n, d = nest.arc.input_args()
            
            if n == props.n then
                local en = props.en[1]
                props.en[2](props.en[1] + d * props.sens * 2)

                nest.arc.make_dirty()
            end
        elseif nest.arc.is_drawing() then
            if not recorded then
                if recording then
                    local st = props.x[1]
                    local en = props.x[1] - 1 + math.ceil(
                        reg:get_end('fraction')*(props.x[2] - props.x[1] + 2)
                    )
                    a:led(props.n, (st - 1) % 64 + 1 - off, props.lvl_st)
                    a:led(props.n, (en - 1) % 64 + 1 - off, props.lvl_st)
                end
            else
                local st = props.x[1] + math.ceil(
                    props.st[1]*(props.x[2] - props.x[1] + 2)
                )
                local en = props.x[1] - 1 + math.ceil(
                    props.en[1]*(props.x[2] - props.x[1] + 2)
                )
                local ph = props.x[1] + util.round(
                    props.phase * (props.x[2] - props.x[1])
                )

                a:led(props.n, (st - 1) % 64 + 1 - off, props.lvl_st)
                a:led(props.n, (en - 1) % 64 + 1 - off, props.lvl_en)
                if props.show_phase then 
                    a:led(props.n, (ph - 1) % 64 + 1 - off, props.lvl_ph)
                end
            end
        end
    end
end

return Components
