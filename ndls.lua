-- ndls
--
-- -- - -- --- -  ---- -- - ---  -- - - ---
-- -- - --- - --- - -- - --- - - - - - ---
--  --- --- -- - ---- -- - - -- - --- -----
-- -   --- - -- -- -- - -   -- - -- --- --
--
-- endless and/or noodles
--
-- version 1.0-beta @andrew
--

--external libs

cs = require 'controlspec'
pattern_time = require 'pattern_time'
UI = require 'ui'

nest = include 'lib/nest/core'
Key, Enc = include 'lib/nest/norns'
Text = include 'lib/nest/text'
Grid = include 'lib/nest/grid'
Arc = include 'lib/nest/arc'

multipattern = include 'lib/nest/util/pattern-tools/multipattern'
of = include 'lib/nest/util/of'
to = include 'lib/nest/util/to'
PatternRecorder = include 'lib/nest/examples/grid/pattern_recorder'

cartographer, Slice = include 'lib/cartographer/cartographer'

--globals

function pattern_time:resume()
    if self.count > 0 then
        self.prev_time = util.time()
        self.process(self.event[self.step])
        self.play = 1
        self.metro.time = self.time[self.step] * self.time_factor
        self.metro:start()
    end
end

pattern, mpat = {}, {}
for i = 1,8 do
    pattern[i] = pattern_time.new() 
    mpat[i] = multipattern.new(pattern[i])
end

voices = 4
buffers = 4

view_matrix = false
view = {}
vertical = true
alt = false
norns_view = 1

local g = grid.connect()
local a = arc.connect()

function g64()
    return g and g.device and g.device.cols < 16 or false
end

local greg = function()
    return reg.play
end

local set_start_scoped = {}
for i = 1, buffers do
    set_start_scoped[i] = multipattern.wrap_set(mpat, 'start '..i, function(v) 
        greg()[i]:set_start(v, 'fraction')
        nest.screen.make_dirty(); nest.arc.make_dirty()
    end)
end
local set_end_scoped = {}
for i = 1, buffers do
    set_end_scoped[i] = multipattern.wrap_set(mpat, 'end '..i, function(v) 
        greg()[i]:set_end(v, 'fraction')
        nest.screen.make_dirty(); nest.arc.make_dirty()
    end)
end
get_set_start = function(voice)
    local buffer = sc.buffer[voice]
    return set_start_scoped[scoped]
end
get_start = function(voice, units)
    units = units or 'fraction'
    return greg():get_start(voice, units)
end
get_set_end = function(voice)
    local buffer = sc.buffer[voice]
    return set_end_scoped[scoped]
end
get_end = function(voice, units)
    units = units or 'fraction'
    return greg():get_end(voice, units)
end
get_len = function(voice, units)
    units = units or 'fraction'
    return greg():get_length(voice, units)
end

--internal files

sc, reg = include 'ndls/lib/softcut'               --softcut utilities
include 'ndls/lib/params'                          --create params
Components = include 'ndls/lib/ui/components'      --UI components
App = {}
App.grid = include 'ndls/lib/ui/grid'              --grid UI
App.arc = include 'ndls/lib/ui/arc'                --arc UI
App.norns = include 'ndls/lib/ui/norns'            --norns UI

--set up nest v2 UI

local _app = {
    grid = App.grid(not g64(), 0),
    arc = App.arc({ 'vol', 'cut', 'st', 'len' }),
    norns = App.norns(),
}

nest.connect_grid(_app.grid, g, 60)
nest.connect_arc(_app.arc, a, 90)
nest.connect_enc(_app.norns)
nest.connect_key(_app.norns)
nest.connect_screen(_app.norns)

function init()
    sc.setup()

    params:read()
    for i = 1, voices do
        params:set('vol '..i, 1)
        --params:set('bnd '..i, 0)
        params:set('cut '..i, 1)
        params:set('type '..i, 1)
        params:set('rec '..i, 0)
        params:set('play '..i, 0)
        params:set('rate '..i, 0)
        params:set('rev '..i, 0)
        --params:set('crossfade assign '..i, i <3 and 2 or 3)
    end
    --params:set('crossfade', 0)

    params:bang()
end

function cleanup()
    params:write()
end
