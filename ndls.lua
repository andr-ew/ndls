-- ndls
--
-- . . . . @ @ . . . @ @ . . . . 
-- . . . @ . . @ . @ . . @ . . . 
-- . . . @ . . @ . @ . . @ . . . 
-- . . . . @ @ . . . @ @ . . . . 
-- . . . . . . @ @ @  . . . . . . 
--
-- 4-track tape looper, delay, 
-- & sampler
--
-- version 0.3.0-beta @andrew
--
-- required: grid 
-- (128, 64, or midigrid)
--
-- documentation:
-- github.com/andr-ew/ndls

--device globals (edit for midigrid)

g = grid.connect()
a = arc.connect()

wide = g and g.device and g.device.cols >= 16 or false
tall = g and g.device and g.device.rows >= 16 or false
arc2 = a and a.device and string.match(a.device.name, 'arc 2')
arc_connected = not (a.name == 'none')

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
filtergraph = require 'filtergraph'
fileselect = require 'fileselect'

--git submodule libs

include 'lib/crops/core'                                 --crops, a UI component framework
Grid = include 'lib/crops/components/grid'
Arc = include 'lib/crops/components/arc'
Enc = include 'lib/crops/components/enc'
Key = include 'lib/crops/components/key'
Screen = include 'lib/crops/components/screen'

pattern_time = include 'lib/pattern_time_extended/pattern_time_extended'

Produce = {}
Produce.grid = include 'lib/produce/grid'                --some extra UI components

cartographer = include 'lib/cartographer/cartographer'   --a buffer management library

--script files

metaparams = include 'ndls/lib/metaparams'               --abstraction around params
windowparams = include 'ndls/lib/windowparams'           --abstraction around params
include 'ndls/lib/globals'                               --global variables
sc, reg = include 'ndls/lib/softcut'                     --softcut utilities
include 'ndls/lib/params'                                --create (meta)params
Components = include 'ndls/lib/ui/components'            --ndls's custom UI components
App = {}
App.grid = include 'ndls/lib/ui/grid'                    --grid UI
App.arc = include 'ndls/lib/ui/arc'                      --arc UI
App.norns = include 'ndls/lib/ui/norns'                  --norns UI

--create, connect UI components

_app = {
    --grid = App.grid(not g64(), 0),
    grid = App.grid{ 
        wide = wide, tall = tall,
        varibright = varibright 
    },
    arc = App.arc{ 
        map = not arc2 and { 'gain', 'cut', 'st', 'len' } or { 'st', 'len', 'gain', 'cut' }, 
        rotated = arc2,
        grid_wide = wide,
    },
    norns = App.norns(),
}

crops.connect_grid(_app.grid, g, fps.grid)
crops.connect_arc(_app.arc, a, fps.arc)
crops.connect_enc(_app.norns)
crops.connect_key(_app.norns)
screen_clock = crops.connect_screen(_app.norns, fps.screen)

--init/cleanup

function init()
    sc.init()

    if 
        -- false and --for testing
        util.file_exists(
        norns.state.data..norns.state.shortname..'-'..string.format("%02d", pset_default_slot)..'.pset'
    ) then
        params:read(pset_default_slot)
    else
        params:bang()
        params:write(pset_default_slot, 'default')
    end
end

function cleanup()
    params:write(pset_last_session_slot, 'last session')

    if params:string('autosave pset') == 'yes' then params:write(pset_default_slot, 'default') end
end
