local pattern, mpat = {}, {}
for i = 1,ndls.voices do
    pattern[i] = pattern_time.new() 
    mpat[i] = multipattern.new(pattern[i])
end

local view = {
    { 1, 0, 0, 0 },
    { 1, 0, 0, 0 },
    { 1, 0, 0, 0 },
    { 1, 0, 0, 0 },
}

local function View(vertical)
    local held = {}

    vertical = vertical or true

    return function(props)
        local g = nest.grid.device()

        if nest.grid.has_input() then
            local x, y, z = nest.grid.input_args()
            
            local dx, dy = x - props.x + 1, y - props.y + 1
            if z == 1 then
                table.insert(held, { x = dx, y = dy })

                if #held > 1 then
                    if held[1].x == held[2].x then vertical = true
                    elseif held[1].y == held[2].y then vertical = false end
                end

                for i = 1,4 do --y
                    for j = 1,4 do --x 
                        props.state[i][j] = (
                            vertical and dx == j
                        )
                            and 1 
                            or ((not vertical and dy == i) and 1 or 0)
                    end 
                end

                nest.grid.make_dirty()
            else
                for i,v in ipairs(held) do
                    if v.x == dx and v.y == dy then table.remove(held, i) end
                end
            end
        elseif nest.grid.is_drawing() then
            for i = 0,3 do for j = 0,3 do 
                g:led(props.x + j, props.y + i, props.state[i + 1][j + 1] * props.lvl)
            end end               
        end
    end
end

local function Phase()
    return function(props)
        local g = nest.grid.device()

        if nest.grid.is_drawing() then
            g:led(
                props.x[1] 
                    + util.round(sc.phase[n].rel * (props.x[2] - props.x[1])), 
                props.y, 
                8
            )
        end
    end
end

local App = {}

local function App.grid(size)
    local shaded = varibright and { 4, 15 } or { 0, 15 }
    local mid = varibright and 4 or 15
    local mid2 = varibright and 8 or 15

    --local _patrec = PatternRecorder()

    local function Voice(n)
        local top, bottom = n, n + 4

        _phase = Phase()
        
        local _params = {}
        _params.rec = to.pattern(mpat, 'rec '..n, Grid.toggle, function()
            return {
                x = 1, y = bottom, 
                state = of.param('rec '..n),
            }
        end)
        _params.play = to.pattern(mpat, 'play '..n, Grid.toggle, function()
            local recorded = sc.punch_in[ndls.zone[n]].recorded
            local recording = sc.punch_in[ndls.zone[n]].recording

            return {
                x = 2, y = bottom, lvl = shaded,
                state = {
                    recorded and params:get('play '..n) or 0,
                    function(v)
                        if recorded or recording then 
                            params:set('play '..n, v)
                        end
                    end
                },
            }
        end)
        --_zoom = Grid.toggle
        _params.zone = to.pattern(mpat, 'zone '..n, Grid.number, function()
            return {
                x = { 4, 13 }, y = bottom,
                state = {
                    ndls.zone[n],
                    function(v) ndls.zone:set(v, n) end
                }
            }
        end)
        _params.send = to.pattern(mpat, 'send '..n, Grid.toggle, function()
            return {
                x = 14, y = bottom, lvl = shaded,
                state = of.param('send '..n),
            }
        end)
        _params.ret = to.pattern(mpat, 'return '..n, Grid.toggle, function()
            return {
                x = 15, y = bottom,
                state = of.param('return '..n),
            }
        end)
        _params.rev = to.pattern(mpat, 'rev '..n, Grid.toggle, function()
            return {
                x = 5, y = top, edge = 'falling', lvl = shaded,
                state = { params:get('rev '..n) },
                action = function(v, t)
                    sc.slew(n, (t < 0.2) and 0.025 or t)
                    params:set('rev '..n, v)
                end,
            }
        end)
        _params.rate = to.pattern(mpat, 'rate '..n, Grid.number, function()
            return {
                x = { 6, 15 }, y = top,
                state = { params:get('rate '..n) + 8 },
                action = function(v, t)
                    sc.slew(n, t)
                    params:set('rate '..n, v - 8)
                end,
            }
        end)

        return function()
            _phase{ 
                x = { 1, 16 }, y = top,
                phase = sc.phase[n].rel,
            }

            for _, _param in pairs(_params) do _param() end
        end
    end

    _voices = {}
    for i = 1, ndls.voices do
        _voices[i] = Voice(i)
    end

    _view = View()

    return function()
        for i, _voice in ipairs(_voices) do
            _voice{}
        end

        _view{
            x = 1, y = 1, lvl = 15,
            state = view,
        }
    end
end

function App.arc()
    local rsens = 1/1000

    

    return function()
    end
end

nest.connect_grid(App.grid(), grid.connect(), 60)
nest.connect_arc(App.arc(), arc.connect(), 60)

--[[
nest.connect_arc(_app, arc.connect())
nest.connect_enc(_app)
nest.connect_key(_app)
nest.connect_screen(_app)
--]]
