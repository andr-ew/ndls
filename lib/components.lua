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

function Components.grid.view()
    local held = {}

    return function(props)
        local g = nest.grid.device()

        local vertical = props.vertical[1]
        local set_vertical = props.vertical[2]

        if nest.grid.has_input() then
            local x, y, z = nest.grid.input_args()
            
            if
                x >= props.x and x <= props.x + 3 
                    and y >= props.y and y <= props.y + 3 
            then
                local dx, dy = x - props.x + 1, y - props.y + 1

                if z == 1 then
                    table.insert(held, { x = dx, y = dy })

                    if #held > 1 then
                        if held[1].x == held[2].x then 
                            vertical = true
                            set_vertical(true)
                        elseif held[1].y == held[2].y then 
                            vertical = false
                            set_vertical(false) 
                        end
                    end

                    for i = 1,4 do --y
                        for j = 1,4 do --x 
                            props.view[i][j] = (
                                vertical and dx == j
                            )
                                and 1 
                                or ((not vertical and dy == i) and 1 or 0)
                        end 
                    end

                    props.action()
                    nest.grid.make_dirty()
                else
                    for i,v in ipairs(held) do
                        if v.x == dx and v.y == dy then table.remove(held, i) end
                    end
                end
            end
        elseif nest.grid.is_drawing() then
            for i = 0,3 do for j = 0,3 do 
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
                8
            )
        end
    end
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

--TODO: pattern recording
function Components.arc.st(mpat)
    return function(props)
        local a = nest.arc.device()
        
        if nest.arc.has_input() then
            local n, d = nest.arc.input_args()
            
            if n == props.n then
                if props.nudge then 
                    props.reg:delta_start(props.nreg, d * props.sens, 'fraction') 
                else 
                    props.reg:delta_startend(props.nreg, d * props.sens * 2, 'fraction') 
                end

                nest.arc.make_dirty()
            end
        elseif nest.arc.is_drawing() then
            local st = props.x[1] + math.ceil(
                props.reg:get_start(props.nreg, 'fraction')*(props.x[2] - props.x[1] + 2)
            )
            local en = props.x[1] - 1 + math.ceil(
                props.reg:get_end(props.nreg, 'fraction')*(props.x[2] - props.x[1] + 2)
            )
            local ph = props.x[1] + util.round(
                props.phase * (props.x[2] - props.x[1])
            )
            local show = props.show_phase
            for x = st,en do
                a:led(props.n, (x - 1) % 64 + 1, props.lvl[(x==ph and show) and 2 or 1])
            end
        end
    end
end

--TODO: pattern recording
function Components.arc.len(mpat)
    return function(props)
        local a = nest.arc.device()
        
        if nest.arc.has_input() then
            local n, d = nest.arc.input_args()
            
            if n == props.n then
                if props.nudge then 
                    props.reg:delta_start(props.nreg, d * props.sens, 'fraction') 
                else 
                    props.reg:delta_length(props.nreg, d * props.sens * 2, 'fraction') 
                end

                nest.arc.make_dirty()
            end
        elseif nest.arc.is_drawing() then
            local st = props.x[1] + math.ceil(
                props.reg:get_start(props.nreg, 'fraction')*(props.x[2] - props.x[1] + 2)
            )
            local en = props.x[1] - 1 + math.ceil(
                props.reg:get_end(props.nreg, 'fraction')*(props.x[2] - props.x[1] + 2)
            )
            local ph = props.x[1] + util.round(
                props.phase * (props.x[2] - props.x[1])
            )

            a:led(props.n, (st - 1) % 64 + 1, props.lvl_st)
            a:led(props.n, (en - 1) % 64 + 1, props.lvl_en)
            if props.show_phase then 
                a:led(props.n, (ph - 1) % 64 + 1, props.lvl_ph)
            end
        end
    end
end

return Components
