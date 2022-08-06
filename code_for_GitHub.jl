using DataFrames
using MathOptInterface
using JuMP, GLPK
using CSV

num_lineups = 25
num_overlap = 6
path_hitters = "Hitters.csv"
path_pitchers = "Pitchers.csv"
path_to_output = "output.csv"

# This is a function that creates one lineup using the Type 4 formulation from the paper
function one_lineup_Type_4(hitters, pitchers, lineups, num_overlap, num_hitters, num_pitchers, catcher, first_baseman, second_baseman, third_baseman, shortstop, outfielders, num_teams, hitters_teams, pitchers_opponents)
    m = Model(GLPK.Optimizer)
    
    
    # Variable for Hitters in lineup
    @variable(m, hitters_lineup[i=1:num_hitters], Bin)
    
    # Variable for Pitcher in lineup
    @variable(m, pitchers_lineup[i=1:num_pitchers], Bin)

    # One Pitcher constraint
    @constraint(m, sum(pitchers_lineup[i] for i=1:num_pitchers) == 1)
    
    # Eight Hitters constraint
    @constraint(m, sum(hitters_lineup[i] for i=1:num_hitters) == 8)
    
    # between 1 and 2 catchers + first baseman
    @constraint(m, sum((catcher)[i]*hitters_lineup[i] for i=1:num_hitters) <= 2)
    @constraint(m, 1 <= sum(catcher[i]*hitters_lineup[i] for i=1:num_hitters))
    
    # between 1 and 2 second basemen
    @constraint(m, sum(second_baseman[i]*hitters_lineup[i] for i=1:num_hitters) <= 2)
    @constraint(m, 1 <= sum(second_baseman[i]*hitters_lineup[i] for i=1:num_hitters))
    
    # between 1 and 2 third basemen
    @constraint(m, sum(third_baseman[i]*hitters_lineup[i] for i=1:num_hitters) <= 2)
    @constraint(m, 1 <= sum(third_baseman[i]*hitters_lineup[i] for i=1:num_hitters))
    
    # between 1 and 2 shortstops
    @constraint(m, sum(shortstop[i]*hitters_lineup[i] for i=1:num_hitters) <= 2)
    @constraint(m, 1 <= sum(shortstop[i]*hitters_lineup[i] for i=1:num_hitters))
    
    # between 3 and 4 outfielders
    @constraint(m, 3 <= sum(outfielders[i]*hitters_lineup[i] for i=1:num_hitters))
    @constraint(m, sum(outfielders[i]*hitters_lineup[i] for i=1:num_hitters) <= 4)

    

    # Financial Constraint
    @constraint(m, sum(hitters[i,:Salary]*hitters_lineup[i] for i=1:num_hitters) + sum(pitchers[i,:Salary]*pitchers_lineup[i] for i=1:num_pitchers) <= 35000)


    # exactly x different teams for the 8 hitters constraint
    @variable(m, used_team[i=1:num_teams], Bin)
    constr = @constraint(m, [i=1:num_teams], used_team[i] <= sum(hitters_teams[t, i]*hitters_lineup[t] for t=1:num_hitters))
    constr = @constraint(m, [i=1:num_teams], sum(hitters_teams[t, i]*hitters_lineup[t] for t=1:num_hitters) == 4*used_team[i])
    @constraint(m, sum(used_team[i] for i=1:num_teams) == 2)
    

    # No pitchers going against hitters
    constr = @constraint(m, [i=1:num_pitchers], 6*pitchers_lineup[i] + sum(pitchers_opponents[k, i]*hitters_lineup[k] for k=1:num_hitters)<=6)

    # Overlap Constraint
    constr = @constraint(m, [i=1:size(lineups)[2]], sum(lineups[j,i]*hitters_lineup[j] for j=1:num_hitters) + sum(lineups[num_hitters+j,i]*pitchers_lineup[j] for j=1:num_pitchers) <= num_overlap)
    
                                                                                                                                                                                                            

    # Objective
    @objective(m, Max, sum(hitters[i,:FPPG]*hitters_lineup[i] for i=1:num_hitters) + sum(pitchers[i,:FPPG]*pitchers_lineup[i] for i=1:num_pitchers) )
    


    # Solve the integer programming problem
    println("Solving Problem...")
    print("\n")
    optimize!(m)
    status = termination_status(m) # optimize! retruns Nothing so termination_status on m must be used

    # Puts the output of one lineup into a format that will be used later
    if status==OPTIMAL # OPTIMAL is an enumeriation of JuMP
        hitters_lineup_copy = Int64[]#Array(Int64)(0)
        for i=1:num_hitters
            if value(hitters_lineup[i]) >= 0.9 && value(hitters_lineup[i]) <= 1.1 # value retrives the value
                # hitters_lineup_copy = vcat(hitters_lineup_copy, fill(1,1))
                push!(hitters_lineup_copy, 1) # push 1 end of to hitters_lineup
            else
                # hitters_lineup_copy = vcat(hitters_lineup_copy, fill(0,1))
                push!(hitters_lineup_copy, 0) # push 1 end of to hitters_lineup
            end
        end
        for i=1:num_pitchers
            if value(pitchers_lineup[i]) >= 0.9 && value(pitchers_lineup[i]) <= 1.1
                # hitters_lineup_copy = vcat(hitters_lineup_copy, fill(1,1))
                push!(hitters_lineup_copy, 1) # push 1 end of to hitters_lineup
            else
                # hitters_lineup_copy = vcat(hitters_lineup_copy, fill(0,1))
                push!(hitters_lineup_copy, 0) # push 1 end of to hitters_lineup
            end
        end
        return(hitters_lineup_copy)
    end
end

#=
formulation is the type of formulation that you would like to use. Feel free to customize the formulations. In our paper we considered
the Type 4 formulation in great detail, but we have included the code for all of the formulations dicussed in the paper here. For instance,
if you would like to create lineups without stacking, change one_lineup_Type_4 below to one_lineup_no_stacking
=#
formulation = one_lineup_Type_4








function create_lineups(num_lineups, num_overlap, path_hitters, path_pitchers, formulation, path_to_output)
    #=
    num_lineups is an integer that is the number of lineups
    num_overlap is an integer that gives the overlap between each lineup
    path_hitters is a string that gives the path to the hitters csv file
    path_pitchers is a string that gives the path to the pitchers csv file
    formulation is the type of formulation you would like to use (for instance one_lineup_Type_1, one_lineup_Type_2, etc.)
    path_to_output is a string where the final csv file with your lineups will be
    =#


    # Load information for hitters table
    hitters = CSV.read(path_hitters, DataFrame)
    
    # Load information for pitchers table
    pitchers = CSV.read(path_pitchers, DataFrame)
    
    # Number of hitters
    num_hitters = size(hitters)[1]
    
    # Number of pitchers
    num_pitchers = size(pitchers)[1]
    
    # catchers stores the information on which players are catchers
    catcher = Array{Int}(undef, 0)
    
    # first baseman stores the information on which players are first baseman
    first_baseman = Array{Int}(undef, 0)
    
    # second baseman stores the information on which players are second baseman
    second_baseman = Array{Int}(undef, 0)
    
    # third baseman stores the information on which players are third baseman
    third_baseman = Array{Int}(undef, 0)
    
    # shortstop stores the information on which players are shortsops
    shortstop = Array{Int}(undef, 0)
    
    # outfielders stores the information on which players are outfielders
    outfielders = Array{Int}(undef, 0)
    
    

    #=
    Process the position information in the hitters file to populate C, 1B, 2B, 3B, SS & OF's with the 
    corresponding correct information
    =#
    for i =1:num_hitters
        if hitters[i,:Position] == "C"
            catcher=vcat(catcher,fill(1,1))
            first_baseman=vcat(first_baseman,fill(0,1))
            second_baseman=vcat(second_baseman,fill(0,1))
            third_baseman=vcat(third_baseman,fill(0,1))
            shortstop=vcat(shortstop,fill(0,1))
            outfielders=vcat(outfielders,fill(0,1))
        elseif hitters[i,:Position] == "1B"
            catcher=vcat(catcher,fill(1,1))
            first_baseman=vcat(first_baseman,fill(0,1))
            second_baseman=vcat(second_baseman,fill(0,1))
            third_baseman=vcat(third_baseman,fill(0,1))
            shortstop=vcat(shortstop,fill(0,1))
            outfielders=vcat(outfielders,fill(0,1))
        elseif hitters[i,:Position] == "2B"
            catcher=vcat(catcher,fill(0,1))
            first_baseman=vcat(first_baseman,fill(0,1))
            second_baseman=vcat(second_baseman,fill(1,1))
            third_baseman=vcat(third_baseman,fill(0,1))
            shortstop=vcat(shortstop,fill(0,1))
            outfielders=vcat(outfielders,fill(0,1))
        elseif hitters[i,:Position] == "3B"
            catcher=vcat(catcher,fill(0,1))
            first_baseman=vcat(first_baseman,fill(0,1))
            second_baseman=vcat(second_baseman,fill(0,1))
            third_baseman=vcat(third_baseman,fill(1,1))
            shortstop=vcat(shortstop,fill(0,1))
            outfielders=vcat(outfielders,fill(0,1))
        elseif hitters[i,:Position] == "SS"
            catcher=vcat(catcher,fill(0,1))
            first_baseman=vcat(first_baseman,fill(0,1))
            second_baseman=vcat(second_baseman,fill(0,1))
            third_baseman=vcat(third_baseman,fill(0,1))
            shortstop=vcat(shortstop,fill(1,1))
            outfielders=vcat(outfielders,fill(0,1))
        else
            catcher=vcat(catcher,fill(0,1))
            first_baseman=vcat(first_baseman,fill(0,1))
            second_baseman=vcat(second_baseman,fill(0,1))
            third_baseman=vcat(third_baseman,fill(0,1))
            shortstop=vcat(shortstop,fill(0,1))
            outfielders=vcat(outfielders,fill(1,1))
        end
    end

    catcher = catcher+first_baseman
    



    # Create team indicators from the information in the hitters file
    teams = unique(hitters[!, :Team])

    # Total number of teams
    num_teams = size(teams)[1]

    # player_info stores information on which team each player is on
    player_info = zeros(Int, size(teams)[1])

    # Populate player_info with the corresponding information
    for j=1:size(teams)[1]
        if hitters[1, :Team] == teams[j]
            player_info[j] =1
        end
    end
    hitters_teams = player_info'


    for i=2:num_hitters
        player_info = zeros(Int, size(teams)[1])
        for j=1:size(teams)[1]
            if hitters[i, :Team] == teams[j]
                player_info[j] =1
            end
        end
        hitters_teams = vcat(hitters_teams, player_info')
    end



    # Create pitcher identifiers so you know who they are playing
    opponents = pitchers[!, :Opponent]
    pitchers_teams = pitchers[!, :Team]
    pitchers_opponents=[]
    for num = 1:size(teams)[1]
        if opponents[1] == teams[num]
            pitchers_opponents = hitters_teams[:, num]
        end
    end
    for num = 2:size(opponents)[1]
        for num_2 = 1:size(teams)[1]
            if opponents[num] == teams[num_2]
                pitchers_opponents = hcat(pitchers_opponents, hitters_teams[:,num_2])
            end
        end
    end




    # Lineups using formulation as the stacking type
    the_lineup= formulation(hitters, pitchers, hcat(zeros(Int, num_hitters + num_pitchers), zeros(Int, num_hitters + num_pitchers)), num_overlap, num_hitters, num_pitchers, catcher, first_baseman, second_baseman, third_baseman, shortstop, outfielders, num_teams, hitters_teams, pitchers_opponents)

    the_lineup2= formulation(hitters, pitchers, hcat(the_lineup, zeros(Int, num_hitters + num_pitchers)), num_overlap, num_hitters, num_pitchers, catcher, first_baseman, second_baseman, third_baseman, shortstop, outfielders, num_teams, hitters_teams, pitchers_opponents)
    tracer = hcat(the_lineup, the_lineup2)
    for i=1:(num_lineups-2)
        try
            thelineup=formulation(hitters, pitchers, tracer, num_overlap, num_hitters, num_pitchers, catcher, first_baseman, second_baseman, third_baseman, shortstop, outfielders, num_teams, hitters_teams, pitchers_opponents)
            tracer = hcat(tracer,thelineup)
        catch e # now breaks if error is encountered
            @error e.msg
            @error "breaking at step $i."
            break
        end
    end
    

    # Create the output csv file
    lineup2 = ""
    for j = 1:size(tracer)[2]
        lineup = ["" "" "" "" "" "" "" "" ""]
    for i =1:num_hitters
            if tracer[i,j] == 1
            if catcher[i]==1
                    if lineup[2]==""
                        lineup[2] = string(hitters[i,1])
                    elseif lineup[9] ==""
                        lineup[9] = string(hitters[i,1])
                    end
                elseif first_baseman[i] == 1
                    if lineup[2] == ""
                        lineup[2] = string(hitters[i,1])
                    elseif lineup[9] == ""
                        lineup[9] = string(hitters[i,1])
                    end
                elseif second_baseman[i] == 1
                    if lineup[3] == ""
                        lineup[3] = string(hitters[i,1])
                    elseif lineup[9] == ""
                        lineup[9] = string(hitters[i,1])
                    end
                elseif third_baseman[i] == 1
                    if lineup[4] == ""
                        lineup[4] = string(hitters[i,1])
                    elseif lineup[9] == ""
                        lineup[9] = string(hitters[i,1])
                    end
                elseif shortstop[i] == 1
                    if lineup[5] == ""
                        lineup[5] = string(hitters[i,1])
                    elseif lineup[9] == ""
                        lineup[9] = string(hitters[i,1])
                    end
                elseif outfielders[i] == 1
                    if lineup[6] == ""
                        lineup[6] = string(hitters[i,1])
                    elseif lineup[7] == ""
                        lineup[7] = string(hitters[i,1])
                    elseif lineup[8] == ""
                        lineup[8] = string(hitters[i,1])   
                    elseif lineup[9] == ""
                        lineup[9] = string(hitters[i,1])
                    end
                end
            end
        end
        for i =1:num_pitchers
            if tracer[num_hitters+i,j] == 1
                lineup[1] = string(pitchers[i,1])
            end
        end
        for name in lineup
            lineup2 = string(lineup2, name, ",")
        end
        lineup2 = chop(lineup2)
        lineup2 = string(lineup2, """
        """)
    end
    outfile = open(path_to_output, "w")
    write(outfile, lineup2)
    close(outfile)
end




# Running the code
create_lineups(num_lineups, num_overlap, path_hitters, path_pitchers, formulation, path_to_output)
