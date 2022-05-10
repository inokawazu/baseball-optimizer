using JuMP
using Cbc
using DataFrames
using CSV

path_salaries = "Desktop/DKSalaries.csv"

#Optimization rules - Draftkings
salary_cap = 50000
num_teams = 2
p = 2
c = 1
fb = 1
sb = 1
tb = 1
ss = 1
of = 3

#data load
#you'll need to set your working directory
df = CSV.read(path_salaries)

#position encodings
pitcher = ["P"]
first_base = ["1B"]
second_base = ["2B"]
third_base = ["3B"]
center = ["C"]
outfield = ["OF"]
short_stop = ["SS"]

#setup model matrices
player_positions = split.(df[:Position], "/")
function getPosition(pp, pos_encodings)
  pp_out = zeros(size(pp)[1])
  for i = 1:size(pp)[1]
    push_flag = 0
    for x = 1:size(pp[i])[1]
      for z = 1:size(pos_encodings)[1]
        if pp[i][x] == pos_encodings[z]
          pp_out[i] = 1
          push_flag = 1
          break
        end
      end
      if push_flag == 1
        break
      end
    end
      if push_flag == 0
        pp_out[i] = 0
      end
  end
  return(pp_out)
end

function getDummyTeams(teams)
    mat = zeros(size(teams)[1], length(unique(teams)))
    unique_teams = unique(teams)
    for i = 1:size(teams)[1]
      for x = 1:length(unique_teams)
        if teams[i] == unique_teams[x]
          mat[i,x] = 1
        end
      end
    end
    names(mat) = unique_teams
    return(mat)
end

pitcher = getPosition(player_positions, pitcher)
first_base = getPosition(player_positions, first_base)
second_base = getPosition(player_positions, second_base)
third_base = getPosition(player_positions, third_base)
center = getPosition(player_positions, center)
outfield = getPosition(player_positions, outfield)
short_stop = getPosition(player_positions, short_stop)
teams = getDummyTeams(df[:Team])
unique_teams = unique(df[:Team])

#setup optimization model
m = Model(solver = CbcSolver())

#create our binary variable to choose a player
@variable(m, x[1:size(df)[1]], Bin)
@variable(m, opt_team[1:length(unique_teams)], Bin)

#setup salary constraint
@constraint(m, sum(x .* df[:Salary]) <= salary_cap)
@constraint(m, sum(x) == 10)

#setup max teams constraint for stacking
@constraint(m, sum(opt_team) == num_teams)

#set constraint for which teams can be selected
for j = 1:size(teams)[1]
  for k = 1:size(teams)[2]
    if teams[j,k] == 1
      @constraint(m, x[j] * teams[j, k] <= opt_team[k])
    end
  end
end

#setup position constraints
@constraint(m, sum(x .* pitcher) >= p)
@constraint(m, sum(x .* first_base) >= fb)
@constraint(m, sum(x .* center) >= c)
@constraint(m, sum(x .* second_base) >= sb)
@constraint(m, sum(x .* third_base) >= tb)
@constraint(m, sum(x .* short_stop) >= ss)
@constraint(m, sum(x .* outfield) >= of)

#setup objective
@objective(m, Max, sum(x .* df[:FPPG]))
status = solve(m)
println("Objective value: ", getobjectivevalue(m))

selected = getvalue(x)

#print out summary stats
selected_team = df[selected .> .9, :] #rounding issues
println("Total salary: ", sum(selected_team[:Salary]))
println("Projected points per game: ", sum(selected_team[:FPPG]))
println("Unique teams: ", length(unique(selected_team[:Team])))
println(selected_team)


