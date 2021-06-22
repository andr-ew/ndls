-- endless and/or noodles

--external libs
include 'ndls/lib/nest/core'
include 'ndls/lib/nest/grid'
include 'ndls/lib/nest/arc'
include 'ndls/lib/nest/txt'

ndls = include 'lib/globals'             --shared values
mp = include 'lib/metaparam'             --multi-scope wrapper around params
mpat, mpats = include 'lib/metapattern'  --multi-scope wrapper around pattern_time

for i = 1,8 do mpats[i] = mpat:new() end

--TODO: metaparams

--TODO: nest_
