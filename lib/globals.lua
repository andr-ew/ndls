local ndls = {}

ndls.voices = 4
ndls.zones = 9 --zone count

ndls.zone =  { --active zone
    1, 2, 3, 4,
    entered = {},
    copy = function(s, src, dst)
    end,
    set = function(s, z, n)
        --copy mparam vals from last to new
    end,
    get = function(s, n)
        return s[n]
    end
} 
for i = 1, ndls.voices do
    ndls.zone.entered[i] = {}
    for j = 1, ndls.zones do
        ndls.zone.entered[i][j] = false
    end
end

function ndls.copy(src, dst, range)
    --copy zone, punch_in, region
end

return ndls
