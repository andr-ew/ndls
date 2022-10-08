-- ndls
--
-- -- - -- --- -  ---- -- - ---  -- - - ---
-- -- - --- - --- - -- - --- - - - - - ---
--  --- --- -- - ---- -- - - -- - --- -----
-- -   --- - -- -- -- - -   -- - -- --- --
--
-- endless and/or noodles
--
-- version 0.1.2-beta-persistence @andrew

--device globals (edit for midigrid)

g = grid.connect()
a = arc.connect()

wide = g and g.device and g.device.cols >= 16 or false
tall = g and g.device and g.device.rows >= 16 or false
arc2 = a and a.device and string.match(a.device.name, 'arc 2')

-- test grid64
-- wide = false
-- arc2 = true
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

metaparams = include 'ndls/lib/metaparams'             --abstraction around params
windowparams = include 'ndls/lib/windowparams'         --abstraction around params
include 'ndls/lib/globals'                             --global variables
sc, reg = include 'ndls/lib/softcut'                   --softcut utilities
include 'ndls/lib/params'                              --create (meta)params
Components = include 'ndls/lib/ui/components'          --UI components
App = {}
App.grid = include 'ndls/lib/ui/grid'                  --grid UI
App.arc = include 'ndls/lib/ui/arc'                    --arc UI
App.norns = include 'ndls/lib/ui/norns'                --norns UI

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

nest.connect_grid(_app.grid, g, fps.grid)
nest.connect_arc(_app.arc, a, fps.arc)
nest.connect_enc(_app.norns)
nest.connect_key(_app.norns)
nest.connect_screen(_app.norns, fps.screen)

--init/cleanup

local default_slot = 1
local last_session_slot = 2

function init()
    sc.init()

    if 
        false and --for testing
        util.file_exists(
        norns.state.data..norns.state.shortname..'-'..string.format("%02d", default_slot)..'.pset'
    ) then
        params:read(default_slot)
    else
        params:bang()
        params:write(default_slot, 'default')
    end
end

function cleanup()
    params:write(last_session_slot, 'last session')
end
