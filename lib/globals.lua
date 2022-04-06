local ndls = {}

--TODO 6 voices for 256 grid (?)
ndls.voices = 4
ndls.zones = 10 --zone count
ndls._phase = {}

--TODO: store this data in sc only. sc is really all our global data so there's no need to have this file at all.

ndls.zone =  { --active zone
    1, 2, 3, 4,
    entered = {},
    --zoomed = {},
    set = function(s, z, n)
        local zlast = s[n]
        s[n] = z

        sc.reg.zone[n] = z; sc.reg:update(n)

        nest.arc.make_dirty()
        nest.screen.make_dirty()
    end,
    --[[
    get = function(s, n)
        return s[n]
    end,
    ]]
    init = function(s)
        for n = 1,ndls.voices do sc.reg:update(n) end
    end,
    copy = function(src, dst, range)
       --copy punch_in, region, set entered false for all voices
    end
}

for i = 1, ndls.voices do
    ndls.zone.entered[i] = {}
    --ndls.zoomed[i] = {}
    for j = 1, ndls.zones do
        ndls.zone.entered[i][j] = false
        --ndls.zoomed[i][j] = false
    end
end

for i = 1, ndls.voices do ndls.zone.entered[i][i] = true end

return ndls
