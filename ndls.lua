include "nest_"

g_ = grid_:new()
s_ = screen_:new()

g_.channels = {}

for i = 1, 4 do
    g_.channels[i] = {
        top = {
            gene = gene:new{ y = i },
            divide = momentary:new{
                x = 0,
                output.disabled = true
            },
            speed = Glide:new{
                x = {1, 14},
                v= 7
            },
            phase = value:new{
                x = {0, 15},
                input.disabled = true,
                output.z = -1
            },
            reverse = toggle:new{
                x = 15,
                output.disabled = true
            }
        },
        bottom = {
            gene = gene:new{ y = i + 4 },
            record = toggle:new{
                x = 0,
                off = 4
            },
            play = toggle:new{
                x = 1
            },
            buffer = value:new{
                x = {2, 5},
                v = i
            },
            sync = toggle:new{
                x = 6,
                off = 4
            },
            route = momentary:new{
                x = {7, 10}
            },
            glide = toggle:new{
                x = 11,
                off = 4
            },
            toggle1 = toggle:new{
                x = 12
            },
            toggle2 = toggle:new{
                x = 13
            },
            pattern = pattern:new{
                x = 14,
                target = n
            }
        }
    }
end

s_.sect = {  ---?
    
}

g_.pager = value:new{
    x = 15,
    y = {4, 7},
    bg = 4
}

s_.pager = tabs:new{
        x = { LEFT, RIGHT }, --no
        count = 3
    }
} 


