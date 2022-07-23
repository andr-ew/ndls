-- ndls
--
-- -- - -- --- -  ---- -- - ---  -- - - ---
-- -- - --- - --- - -- - --- - - - - - ---
--  --- --- -- - ---- -- - - -- - --- -----
-- -   --- - -- -- -- - -   -- - -- --- --
--
-- endless and/or noodles
--
-- version 0.1.1-beta-alt-pagination.1 @andrew

--device globals (edit for midigrid)

g = grid.connect()
a = arc.connect()

wide = g and g.device and g.device.cols >= 16 or false
tall = g and g.device and g.device.rows >= 16 or false
arc2 = a and a.device and string.match(a.device.name, 'arc 2')

-- test grid64
wide = false
arc2 = true
-- end test
-- test grid256
-- wide = true
-- tall = true
-- end test

varibright = true

--system libs

cs = require 'controlspec'
pattern_time = require 'pattern_time'
UI = require 'ui'

--git submodule libs

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

--script files

include 'ndls/lib/globals'                         --global variables
sc, reg = include 'ndls/lib/softcut'               --softcut utilities
include 'ndls/lib/params'                          --create params
Components = include 'ndls/lib/ui/components'      --UI components
App = {}
App.grid = include 'ndls/lib/ui/grid'              --grid UI
App.arc = include 'ndls/lib/ui/arc'                --arc UI
App.norns = include 'ndls/lib/ui/norns'            --norns UI

--set up nest v2 UI

local _app = {
    --grid = App.grid(not g64(), 0),
    grid = App.grid{ 
        wide = wide, tall = tall,
        varibright = varibright 
    },
    arc = App.arc{ 
        arc2 = arc2,
        rotated = arc2,
        grid_wide = wide,
    },
    norns = App.norns(),
}

nest.connect_grid(_app.grid, g) --, 60) --TEST
nest.connect_arc(_app.arc, a, 90)
nest.connect_enc(_app.norns)
nest.connect_key(_app.norns)
nest.connect_screen(_app.norns)

--init/cleanup

function init()
    sc.setup()

    params:read()
    for i = 1, voices do
        params:set('vol '..i, 1)
        params:set('bnd '..i, 0)
        params:set('cut '..i, 1)
        params:set('type '..i, 1)
        params:set('rate '..i, 0)
        params:set('rev '..i, 0)
        params:set('rec '..i, 0)
        params:set('play '..i, 0)
        params:set('buffer '..i, i)
        --params:set('crossfade assign '..i, i <3 and 2 or 3)
    end
    --params:set('crossfade', 0)

    params:bang()
end

function cleanup()
    params:write()
end
