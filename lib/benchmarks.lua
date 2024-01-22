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

local vals_dest = { bnd = 1 }

function bench.bnd_min(data)
    sc.ratemx[1].bnd = data; sc.ratemx:update(1)
end

local id = 'bnd_track_1'
local i = 1

local vals_actions = { 
    bnd = function(bnd)
        if bnd ~= sc.ratemx[i].bnd then
            sc.ratemx[i].bnd = bnd; sc.ratemx:update(i) 
            crops.dirty.screen = true; crops.dirty.arc = true
        end
    end 
}

function bench.bnd_min_param(data)
    local v = params:get(id) + data
    local bnd = v
    if bnd ~= sc.ratemx[i].bnd then
        sc.ratemx[i].bnd = bnd; sc.ratemx:update(i) 
        crops.dirty.screen = true; crops.dirty.arc = true
    end
end

function bench.bnd_min_param2(data)
    vals_actions.bnd(data + vals_dest.bnd)
end

local bench_action = patcher.add_source('benchmark_1')

bench.bnd_patcher = bench_action

function bench.run()
    local its, steps = 5, 10000
    
    print('------ BENCH: bnd_min --------')
    tab.print(bench.perform(its, steps, bench.bnd_min))
    
    print('------ BENCH: bnd_min_param2 --------')
    tab.print(bench.perform(its, steps, bench.bnd_min_param2))

    print('------ BENCH: bnd_min_param --------')
    tab.print(bench.perform(its, steps, bench.bnd_min_param))
    
    print('------ BENCH: bnd_patcher --------')
    patcher.set_assignment('benchmark_1', 'bnd_track_1')
    tab.print(bench.perform(its, steps, bench.bnd_patcher))
end

return bench
