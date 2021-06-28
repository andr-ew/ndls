local ndls = {}

ndls.voices = 4
ndls.zones = 9 --zone count

ndls.zone =  { --active zone
    1, 2, 3, 4,
    entered = {},
    set = function(s, z, n)
        print(s.entered[n][z])
        if not s.entered[n][z] then
            mparams:copy(n, s[n], z)
            s.entered[n][z] = true
        else mparams:bang(n, 'zone') end --TODO not wrk usually

        sc.zone[n] = z; sc.zone:update(n)
        s[n] = z
    end,
    get = function(s, n)
        return s[n]
    end,
    init = function(s)
        for n = 1,ndls.voices do sc.zone:update(n) end
    end,
    copy = function(src, dst, range)
       --copy punch_in, region, set entered false for all voices
    end
} 
for i = 1, ndls.voices do
    ndls.zone.entered[i] = {}
    for j = 1, ndls.zones do
        ndls.zone.entered[i][j] = false
    end
end

for i = 1, ndls.voices do ndls.zone.entered[i][i] = true end

return ndls
