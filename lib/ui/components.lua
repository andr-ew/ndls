local Components = {
    grid = {},
    arc = {},
    screen = {},
}

local _routines = {
    screen = {},
    grid = {},
}

do
    local defaults = {
        text = {},               --list of strings to display. non-numeric keys are displayed as labels with thier values. (e.g. { cutoff = value })
        x = 10,                  --x position
        y = 10,                  --y position
        font_face = 1,           --font face
        font_size = 8,           --font size
        margin = 5,              --pixel space betweeen list items
        levels = { 4, 15 },      --table of 2 brightness levels, 0-15 (text, highligght box)
        focus = 2,               --only this index in the resulting list will be highlighted,
        flow = 'right',          --direction of list to flow: 'up', 'down', 'left', 'right'
        font_headroom = 3/8,     --used to calculate height of letters. might need to adjust for non-default fonts
        padding = 1,             --padding around highlight box
        -- font_leftroom = 1/16,
        fixed_width = nil,
    }
    defaults.__index = defaults

    function _routines.screen.list_highlight(props)
        if crops.device == 'screen' then
            setmetatable(props, defaults)

            if crops.mode == 'redraw' then
                screen.font_face(props.font_face)
                screen.font_size(props.font_size)

                local x, y, i, flow = props.x, props.y, 1, props.flow

                local function txt(v)
                    local focus = i == props.focus
                    local w = props.fixed_width or screen.text_extents(v)
                    local h = props.font_size * (1 - props.font_headroom)

                    if focus then
                        screen.level(props.levels[2])
                        screen.rect(
                            x - props.padding, 
                            --TODO: the nudge is wierd... fix if including in common lib
                            y - h - props.padding + (props.nudge and 0 or 1),
                            w + props.padding*2,
                            h + props.padding*2
                        )
                        screen.fill()
                    end
                    
                    screen.move(x, y)
                    screen.level(focus and 0 or props.levels[1])

                    if flow == 'left' then screen.text_right(v)
                    else screen.text(v) end

                    if flow == 'right' then 
                        x = x + w + props.margin
                    elseif flow == 'left' then 
                        x = x - w - props.margin
                    elseif flow == 'down' then 
                        y = y + h + props.margin
                    elseif flow == 'up' then 
                        y = y - h - props.margin
                    end

                    i = i + 1
                end

                if #props.text > 0 then for _,v in ipairs(props.text) do txt(v) end
                else for k,v in pairs(props.text) do txt(k); txt(v) end end
            end
        end
    end
end

do
    local defaults = {
        text = {},               --list of strings to display. non-numeric keys are displayed as labels with thier values. (e.g. { cutoff = value })
        x = 10,                  --x position
        y = 10,                  --y position
        font_face = 1,           --font face
        font_size = 8,           --font size
        margin = 5,              --pixel space betweeen list items
        levels = { 4, 15 },      --table of 2 brightness levels, 0-15 (text, underline)
        focus = 2,               --only this index in the resulting list will be underlined
        flow = 'right',          --direction of list to flow: 'up', 'down', 'left', 'right'
        font_headroom = 3/8,     --used to calculate height of letters. might need to adjust for non-default fonts
        padding = 1,             --padding below text
        -- font_leftroom = 1/16,
        fixed_width = nil,
    }
    defaults.__index = defaults

    function _routines.screen.list_underline(props)
        if crops.device == 'screen' then
            setmetatable(props, defaults)

            if crops.mode == 'redraw' then
                screen.font_face(props.font_face)
                screen.font_size(props.font_size)

                local x, y, i, flow = props.x, props.y, 1, props.flow

                local function txt(v)
                    local focus = i == props.focus
                    local w = props.fixed_width or screen.text_extents(v)
                    local h = props.font_size * (1 - props.font_headroom)

                    if focus then
                        screen.level(props.levels[2])
                        -- screen.rect(
                        --     x - props.padding, 
                        --     y - h - props.padding,
                        --     (props.fixed_width or w) + props.padding*2,
                        --     h + props.padding*2
                        -- )
                        screen.move(flow == 'left' and x-w or x, y + props.padding + 1)
                        screen.line_width(1)
                        screen.line_rel(w, 0)
                        screen.stroke()
                    end
                    
                    screen.move(x, y)
                    screen.level(props.levels[(i == props.focus) and 2 or 1])

                    if flow == 'left' then screen.text_right(v)
                    else screen.text(v) end

                    if flow == 'right' then 
                        x = x + w + props.margin
                    elseif flow == 'left' then 
                        x = x - w - props.margin
                    elseif flow == 'down' then 
                        y = y + h + props.margin
                    elseif flow == 'up' then 
                        y = y - h - props.margin
                    end

                    i = i + 1
                end

                if #props.text > 0 then for _,v in ipairs(props.text) do txt(v) end
                else for k,v in pairs(props.text) do txt(k); txt(v) end end
            end
        end
    end
end

function _routines.screen.meter(props)
    if crops.device == 'screen' and crops.mode == 'redraw' then
        if props.mark then
            local len = props.length * props.mark
            local w = props.width + 2

            screen.level(props.level_mark)
            screen.line_width(1)

            if props.flow == 'up' then
                screen.move(props.x - 2 - 1, props.y - len)
                screen.line_rel(w, 0)
            else
                screen.move(props.x + len, props.y - 2 - 1)
                screen.line_rel(0, w)
            end
            
            screen.stroke()
        end

        for i = 1,2 do if props.levels[i] > 0 then
            local len = props.length * (i==1 and 1 or props.amount)
            screen.level(props.levels[i])

            if i==2 and props.outline then
                screen.line_width(1)

                if props.flow == 'up' then
                    screen.rect(
                        props.x - props.width/2, props.y,
                        props.width - 1, -len
                    )
                else
                    screen.rect(
                        props.x, props.y - props.width/2,
                        len, props.width - 1
                    )
                end
            else
                screen.move(props.x, props.y)
                screen.line_width(props.width or 1)

                if props.flow == 'up' then
                    screen.line_rel(0, -len)
                else
                    screen.line_rel(len, 0)
                end
            end

            screen.stroke()
        end end
    end
end

function _routines.screen.dial(props)
    if crops.device == 'screen' and crops.mode == 'redraw' then
        if props.mark then
            local prot = 2
            local len = props.length * props.mark
            local w = props.width + prot

            screen.level(props.levels[1])
            screen.line_width(1)

            if props.flow == 'up' then
                screen.move(props.x - prot, props.y - len)
                screen.line_rel(w, 0)
            else
                screen.move(props.x + len, props.y - prot)
                screen.line_rel(0, w)
            end
            
            screen.stroke()
        end
        do
            local len = props.length

            screen.level(props.levels[1])
            screen.move(props.x, props.y)
            screen.line_width(props.width or 1)

            if props.flow == 'up' then
                screen.line_rel(0, -len)
            else
                screen.line_rel(len, 0)
            end

            screen.stroke()
        end
        do
            local prot = 4
            local len = props.length * props.amount
            local w = props.width + prot

            screen.level(props.levels[2])
            screen.line_width(1)

            if props.flow == 'up' then
                screen.move(props.x - prot + 1, props.y - len)
                screen.line_rel(w, 0)
            else
                screen.move(props.x + len, props.y - prot + 1)
                screen.line_rel(0, w)
            end
            
            screen.stroke()
        end
    end
end

function Components.screen.recglyph()
    local blinking = false
    local blink = 0

    local blink_time = 0.4
    clock.run(function()
        while true do
            if blinking then
                blink = 1
                crops.dirty.screen = true
                clock.sleep(blink_time)

                blink = 0
                crops.dirty.screen = true
                clock.sleep(blink_time)
            else
                blink = 0
                clock.sleep(blink_time)
            end
        end
    end)

    return function(props)
        blinking = props.recording
    
        _screen.glyph{
            x = props.x, y = props.y,
            glyph = props.recorded and props.play==1 and [[
                . # # # .
                # # # # #
                # # # # #
                # # # # #
                . # # # .
            ]] or [[
                . # # # .
                # . . . #
                # . . . #
                # . . . #
                . # # # .
            ]],
            levels = {
                ['.'] = 0, 
                ['#'] = (
                    props.recording and props.levels[blink+1]
                    or props.rec==1 and props.levels[2]
                    or props.levels[1]
                )
            }
        }
    end
end

function Components.screen.waveform(args)
    local left, right = args.x[1], args.x[2]
    local width = right - left + 1
    local top, bottom = args.y[1], args.y[2]
    local height = bottom - top + 1
    local equator = math.floor(top + height/2)
    local amp = math.floor(height/2)
    
    sc.samples:init(width)

    return function(props)
        if crops.device == 'screen' and crops.mode == 'redraw' then
            local lvl = props.levels or { window = 15, phase = 4, wave = 1 }
            local reg = props.reg
            local st, en = props.st, props.en
            local ph = props.phase
            local recording = props.recording
            local recorded = props.recorded
            local show_phase = props.show_phase
            local samples = props.samples
            local render = props.render or function() end
            --local rec_flag = props.rec_flag

            screen.level(lvl.wave)
            screen.move(left, equator)
            screen.line_width(1)
            screen.line(right, equator)
            screen.stroke()

            if not recorded then
                if recording then
                    screen.level(lvl.window)
                    screen.move(left + width * reg:get_start('fraction'), equator)
                    screen.line_width(1)
                    screen.line(left + width * reg:get_end('fraction'), equator)
                    screen.stroke()

                    -- crops.dirty.screen = true 
                end
            else
                --waveform
                for i = 1,width do
                    local x = left + i
                    local s = samples[i]
                    if s then
                        local a = util.round(math.min(math.abs(s * 2), 1) * amp)
                        --local db = 20 * math.log(a, 10)
                        local db = a
                        screen.move(x, equator - db - 1)
                        screen.line_width(1)
                        screen.line_rel(0, 2 * db + 1)
                        screen.stroke()
                    end
                end

                screen.level(lvl.window)
                --st
                screen.move(left + width * st, top)
                screen.line_width(1)
                screen.line(left + width * st, bottom)
                screen.stroke()
                --en
                screen.move(left + width * en, top)
                screen.line_width(1)
                screen.line(left + width * en, bottom)
                screen.stroke()
                --phase
                if show_phase then
                    screen.level(lvl.phase)
                    screen.move(left + width * ph, top)
                    screen.line_width(1)
                    screen.line(left + width * ph, bottom)
                    screen.stroke()
                end
                
                render()
                -- crops.dirty.screen = true 
            end
        end
    end
end

function Components.screen.filtergraph(args)
    local fg = filtergraph.new(args.x_min, args.x_max, args.y_min, args.y_max)
        
    fg:set_position_and_size(args.x, args.y, args.w, args.h)

    return function(props)
        if props.filter_type ~= 'bypass' then
            fg:edit(props.filter_type, props.slope, props.freq, props.resonance)
        else
            fg:remove_all_points()
        end
        fg:redraw()
    end
end

function Components.grid.arc_focus()
    local held = {}

    return function(props)
        local tall = props.tall

        local vertical = props.vertical[1]
        local set_vertical = props.vertical[2]

        if crops.device == 'grid' then
            if crops.mode == 'input' then
                local x, y, z = table.unpack(crops.args)
                
                if
                    x >= props.x and x <= props.x + (3) 
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
                    else
                        for i,v in ipairs(held) do
                            if v.x == dx and v.y == dy then table.remove(held, i) end
                        end
                    end
                end
            elseif crops.mode == 'redraw' then
                local g = crops.handler

                for i = 0,tall and 5 or 3 do for j = 0,3 do 
                    g:led(props.x + j, props.y + i, props.levels[props.view[i + 1][j + 1] + 1])
                end end
            end
        end
    end
end

function Components.grid.phase()
    return function(props)
        if crops.mode == 'redraw' then
            local g = crops.handler
            g:led(
                props.x + math.floor(props.phase * props.size), 
                props.y, 
                props.level
            )
        end
    end
end

function Components.grid.togglehold()
    local downtime = nil

    return function(props)
        props.edge = 'falling'
        props.input = function(z)
            if z==1 then
                downtime = util.time()
            elseif z==0 then
                local heldtime = util.time() - downtime

                if heldtime > (props.hold_time or 0.5) then
                    if props.hold_action then props.hold_action(heldtime) end
                end

                downtime = nil --probably extraneous
            end
        end

        _grid.toggle(props)
    end
end

function Components.grid.integerglide()
    local downtime = nil
    local held = false

    return function(props)
        if crops.mode == 'input' and crops.device == 'grid' then 
            local x, y, z = table.unpack(crops.args) 
            local n = _grid.util.xy_to_index(props, x, y)

            if n then 
                local old = crops.get_state(props.state)
                local new = n

                if z==1 then
                    if not held then downtime = util.time() end
                    held = true

                    if new ~= old then
                        local heldtime = util.time() - downtime

                        if props.hold_action then props.hold_action(heldtime) end
                        crops.set_state(props.state, new) 
                        
                        held = false
                    end
                end
            end
        elseif crops.mode == 'redraw' then
            _grid.integer(props)
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

        -- nest.arc.make_dirty()
        -- nest.screen.make_dirty()
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

do
    local index_to_xy = _grid.util.index_to_xy
    local xy_to_index = _grid.util.xy_to_index

    local function binary_get(data, bit) --get bit
        return (data >> (bit-1)) & 1
    end
    -- function binary_set(data, bit) --set bit to 1
    --     return data | (1 << (bit-1))
    -- end
    -- function binary_clear(data, bit) --set bit to 0
    --     return data & ~(1 << (bit-1))
    -- end

    local function binary_toggle(data, bit) --toggle bit
        return data ~ (1 << (bit-1))
    end

    local defaults = {
        state = {0},
        x = 1,                      --x position of the component
        y = 1,                      --y position of the component
        edge = 'rising',            --input edge sensitivity. 'rising' or 'falling'.
        input = function(n, z) end, --input callback, passes last key state on any input
        levels = { 0, 15 },         --brightness levels. expects a table of 2 ints 0-15
        size = 2,                 --total number of keys
        wrap = 16,                  --wrap to the next row/column every n keys
        flow = 'right',             --primary direction to flow: 'up', 'down', 'left', 'right'
        flow_wrap = 'down',         --direction to flow when wrapping. must be perpendicular to flow
        padding = 0,                --add blank spaces before the first key
    }
    defaults.__index = defaults

    function _routines.grid.integerbinary(props)
        if crops.device == 'grid' then
            setmetatable(props, defaults) 

            if crops.mode == 'input' then 
                local x, y, z = table.unpack(crops.args) 
                local n = xy_to_index(props, x, y)

                if n then 
                    props.input(n, z)

                    if
                        (z == 1 and props.edge == 'rising')
                        or (z == 0 and props.edge == 'falling')
                    then
                        local old = crops.get_state(props.state) - 1

                        local new = binary_toggle(old, n) + 1

                        crops.set_state(props.state, new) 
                    end
                end
            elseif crops.mode == 'redraw' then 
                local g = crops.handler 

                for i = 1, props.size do
                    local v = crops.get_state(props.state) - 1

                    local vbit = binary_get(v, i)
                    local lvl = props.levels[vbit + 1] 

                    local x, y = index_to_xy(props, i)
                    if lvl>0 then g:led(x, y, lvl) end
                end
            end
        end
    end
end

function Components.arc.filter()
    return function(props)
        if crops.device == 'arc' and crops.mode == 'redraw' then
            local a = crops.handler
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

function Components.arc.st()
    return function(props)
        if crops.device == 'arc' then
            local recording = props.recording
            local recorded = props.recorded
            --local rec_flag = props.rec_flag
            local reg = props.reg
            local off = props.rotated and 16 or 0
            
            if crops.mode == 'input' then
                local n, d = table.unpack(crops.args)
                
                if n == props.n then
                    --props. 
                    
                    --local st, en = props.state[1].st, props.state[1].en
                    local st = props.st[1]
                    local en = props.en[1]
                    props.st[2](props.st[1] + d * props.sensitivity * 2)
                    props.en[2](props.en[1] + d * props.sensitivity * 2)

                    -- nest.arc.make_dirty()
                end
            elseif crops.mode == 'redraw' then
                local a = crops.handler

                if not recorded then
                    if recording then
                        local st = props.x[1]
                        local en = props.x[1] - 1 + math.ceil(
                            reg:get_end('fraction')*(props.x[2] - props.x[1] + 2)
                        )
                        for x = st,en do
                            a:led(props.n, (x - 1) % 64 + 1 - off, props.levels[1])
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
                        a:led(props.n, (x - 1) % 64 + 1 - off, props.levels[(x==ph and show) and 2 or 1])
                    end
                end
            end
        end
    end
end

function Components.arc.len()
    return function(props)
        if crops.device == 'arc' then
            local recording = props.recording
            local recorded = props.recorded
            --local rec_flag = props.rec_flag
            local reg = props.reg
            local off = props.rotated and 16 or 0
            
            if crops.mode == 'input' then
                local n, d = table.unpack(crops.args)
                
                if n == props.n then
                    local en = props.en[1]
                    props.en[2](props.en[1] + d * props.sensitivity * 2)

                    -- nest.arc.make_dirty()
                end
            elseif crops.mode == 'redraw' then
                local a = crops.handler

                if not recorded then
                    if recording then
                        local st = props.x[1]
                        local en = props.x[1] - 1 + math.ceil(
                            reg:get_end('fraction')*(props.x[2] - props.x[1] + 2)
                        )
                        a:led(props.n, (st - 1) % 64 + 1 - off, props.level_st)
                        a:led(props.n, (en - 1) % 64 + 1 - off, props.level_st)
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

                    a:led(props.n, (st - 1) % 64 + 1 - off, props.level_st)
                    a:led(props.n, (en - 1) % 64 + 1 - off, props.level_en)
                    if props.show_phase then 
                        a:led(props.n, (ph - 1) % 64 + 1 - off, props.level_ph)
                    end
                end
            end
        end
    end
end

return Components, _routines
