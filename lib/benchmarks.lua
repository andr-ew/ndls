local bench = {}

bench.perform = function(nruns, nsteps, fn)
    local times_ms = {}
    local data = {}
    for i = 1,nsteps do data[i] = math.random() * 5 end

    for i=1,nruns do
        _norns.cpu_time_start_timer()
        for j=1,nsteps do
            fn(data[j])
        end
        local delta_ns = _norns.cpu_time_get_delta()
        table.insert(times_ms, delta_ns / 1e6)
    end
    return times_ms
end

local id = 'bnd_track_1'
local i = 1

function bench.bnd_min_param(data)
    local v = params:get(id) + data
    local bnd = v
    if bnd ~= sc.ratemx[i].bnd then
        sc.ratemx[i].bnd = bnd; sc.ratemx:update(i) 
        crops.dirty.screen = true; crops.dirty.arc = true
    end
end

function bench.bnd_patcher(data)
    patcher.set_source('benchmark_'..1, data)
end

return bench
