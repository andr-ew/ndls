local function App(wide, offset)
    local varibright = true
    local shaded = varibright and { 4, 15 } or { 0, 15 }
    local mid = varibright and 4 or 15
    local mid2 = varibright and 8 or 15

    --TODO: only enable when arc is connected AND wide
    view_matrix = wide

    view = view_matrix and {
        { 1, 0, 0, 0 },
        { 1, 0, 0, 0 },
        { 1, 0, 0, 0 },
        { 1, 0, 0, 0 },
    } or { 0, 0, 0, 0 }

    local function Voice(n)
        local top, bottom = n, n + ndls.voices

        local _phase = Components.grid.phase()
        
        local _params = {}
        _params.rec = to.pattern(mpat, 'rec '..n, Grid.toggle, function()
            return {
                x = 1, y = bottom, 
                state = of.param('rec '..n),
            }
        end)
        _params.play = to.pattern(mpat, 'play '..n, Grid.toggle, function()
            return {
                x = 2, y = bottom, lvl = shaded,
                state = {
                    sc.punch_in[ndls.zone[n]].recorded and params:get('play '..n) or 0,
                    function(v)
                        local recorded = sc.punch_in[ndls.zone[n]].recorded
                        local recording = sc.punch_in[ndls.zone[n]].recording

                        if recorded or recording then 
                            params:set('play '..n, v)
                        end
                    end
                },
            }
        end)
        _params.zone = to.pattern(mpat, 'zone '..n, Grid.number, function()
            return {
                x = { 3, 6 }, y = bottom,
                state = {
                    ndls.zone[n],
                    function(v) ndls.zone:set(v, n) end
                }
            }
        end)
        if wide then
            _params.send = to.pattern(mpat, 'send '..n, Grid.toggle, function()
                return {
                    x = 14, y = bottom, lvl = shaded,
                    state = of.param('send '..n),
                }
            end)
            _params.ret = to.pattern(mpat, 'return '..n, Grid.toggle, function()
                return {
                    x = 15, y = bottom, lvl = shaded,
                    state = of.param('return '..n),
                }
            end)
        end
        _params.rev = to.pattern(mpat, 'rev '..n, Grid.toggle, function()
            return {
                x = wide and 5 or 2, y = top, edge = 'falling', lvl = shaded,
                state = { params:get('rev '..n) },
                action = function(v, t)
                    sc.slew(n, (t < 0.2) and 0.025 or t)
                    params:set('rev '..n, v)
                end,
            }
        end)
        do
            local off = wide and 6 or 4
            _params.rate = to.pattern(mpat, 'rate '..n, Grid.number, function()
                return {
                    x = wide and { 6, 13 } or { 3, 8 }, y = top, filtersame = true,
                    state = { params:get('rate '..n) + off },
                    action = function(v, t)
                        sc.slew(n, t)
                        params:set('rate '..n, v - off)
                    end,
                }
            end)
        end

        local _cf_assign = { Grid.toggle(), Grid.toggle() }

        return function()
            _cf_assign[1]{
                x = wide and 14 or 7, y = wide and top or bottom, 
                lvl = shaded,
                state = { params:get('crossfade assign '..n) == 2 and 1 or 0 },
                action = function(v)
                    if v == 1 then
                        params:set('crossfade assign '..n, 2)
                    elseif v == 0 then
                        params:set('crossfade assign '..n, 1)
                    end
                end
            }
            _cf_assign[2]{
                x = wide and 15 or 8, y = wide and top or bottom, 
                lvl = shaded,
                state = { params:get('crossfade assign '..n) == 3 and 1 or 0 },
                action = function(v)
                    if v == 1 then
                        params:set('crossfade assign '..n, 3)
                    elseif v == 0 then
                        params:set('crossfade assign '..n, 1)
                    end
                end
            }

            for _, _param in pairs(_params) do _param() end
            
            if sc.lvlmx[n].play == 1 and sc.punch_in[ndls.zone[n]].recorded then
                _phase{ 
                    x = wide and { 1, 16 } or { 1, 8 }, y = top,
                    phase = sc.phase[n].rel,
                }
            end
        end
    end

    local _view = wide and Components.grid.view() or Grid.toggle()
    
    local _voices = {}
    for i = 1, ndls.voices do
        _voices[i] = Voice(i)
    end

    local _patrec = PatternRecorder()

    local function view_refresh()
         nest.arc.make_dirty()
         nest.screen.make_dirty()
    end

    return function()
        if wide then
            _view{
                x = 1, y = 1, lvl = 15,
                view = view,
                vertical = { vertical, function(v) vertical = v end },
                action = view_refresh
            }
        else
            _view{
                x = 1, y = { 1, 4 }, lvl = 15, count = { 0, 1 },
                state = { 
                    view, 
                    function(v) 
                        view = v 
                        
                        vertical = true
                        for y = 1,ndls.voices do
                            if view[y] > 0 then
                                vertical = false
                            end
                        end

                        view_refresh()
                    end 
                }
            }
        end
        
        for i, _voice in ipairs(_voices) do
            _voice{}
        end
        
        _patrec{
            x = 16, y = { 1, 8 }, pattern = pattern,
        }
    end
end

return App
