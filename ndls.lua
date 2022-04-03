-- ndls
--
-- -- - -- --- -  ---- -- - ---  -- - - ---
-- -- - --- - --- - -- - --- - - - - - ---
--  --- --- -- - ---- -- - - -- - --- -----
-- -   --- - -- -- -- - -   -- - -- --- --
--
-- endless and/or noodles
-- 
-- version 0.1.0 @andrew
--

function r() norns.script.load(norns.script.state) end

--external libs

cartographer, Slice = include 'ndls/lib/cartographer/cartographer'
cs = require 'controlspec'

ndls = include 'ndls/lib/globals'               --shared values
--mpats, mpat = include 'ndls/lib/metapattern'    --multi-scope wrapper around pattern_time
--mparams, mparam = include 'ndls/lib/metaparam'  --multi-scope wrapper around params
sc, reg = include 'ndls/lib/softcut'            --softcut utilities
--cr = include 'ndls/lib/crow'                    --crow utilities


