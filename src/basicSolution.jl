include("parser.jl")
size = "tiny"
input = "instances/KIRO-$size.json"
output = "solutions/KIRO-$(size)_sol1.json"

instance = read_instance(input) :: Instance

using JuMP, HiGHS

model = Model(HiGHS.Optimizer)

# Add x_vs variables
nbSubLocations = length(instance.substationLocations)
nbSubTypes = length(instance.substationTypes)
@variable(model, x[1:nbSubLocations, 1:nbSubLocations], Bin)

# Add the constraints on substation locations. (1)
for i in 1:nbSubLocations
    @constraint(model, sum(x[i, :]) <= 1)
end

 # Add y_eq variables for land-substation cables
 nbLandCableTypes = length(instance.landSubstationCables)
 @variable(model, yland[1:nbSubLocations, 1:nbLandCableTypes], Bin)

 # Add the constraints on the land-substation cables. (2)
for v in 1:nbSubLocations
    @constraint(model, sum(yland[v, :]) == sum(x[v, :]))
end

# Add z_vt variables
nbTurbines = length(instance.windTurbine)
@variable(model, z[1:nbSubLocations, 1:nbTurbines], Bin)

# Add the constraints on the wind turbines. (3)
for t in 1:nbTurbines
    @constraint(model, sum(z[:, t]) == 1)
end

# Add y_eq between substations variables
nbSubCableTypes = length(instance.substationSubstationCables)
@variable(model, ysub[1:nbSubLocations, 1:nbSubLocations, 1:nbSubCableTypes], Bin)

# Add the constraints on the substation-substation cables. (4)
for v in 1:nbSubLocations
    @constraint(model, sum(ysub[v, :, :]) <= sum(x[v, :]))
end

# We will add some parts of the objective function as variables to make it easier to read

# Using what we proved in question 5 of the report
# We can write the no-curtailing cost as follows, by adding two variables per substation
# So as to linearize the [power_received - min(capa_sub, capa_cable)]⁺ terms

#This corresponds to the -min(capa_sub, capa_cable) part
@variable(model, minusCapa[1:nbSubLocations])

substation_ratings = [instance.substationTypes[i].rating for i in 1:nbSubTypes]
landCable_ratings = [instance.landSubstationCables[i].rating for i in 1:nbLandCableTypes]
for v in 1:nbSubLocations
    @constraint(model, minusCapa[v] >= - sum(substation_ratings[i] * x[v, i] for i in 1:nbSubTypes))
    @constraint(model,minusCapa[v] >= - sum(landCable_ratings[i] * yland[v, i] for i in 1:nbLandCableTypes))
end

# We then add variables for the curtailing of each substation under each scenario
nbScenarios = length(instance.scenarios)

@variable(model, curtailing[1:nbSubLocations, 1:nbScenarios])

for ω in 1:nbScenarios
    for v in 1:nbSubLocations
        net_power = instance.scenarios[ω].power * sum(z[v, :]) + minusCapa[v]
        @constraint(model, curtailing[v, ω] >= net_power)
        @constraint(model, curtailing[v, ω] >= 0)
    end
end

# Then add the total curtailing without probability_failure

@variable(model, curtailingNoFailure[1:nbScenarios])
for ω in 1:nbScenarios
    @constraint(model, curtailingNoFailure[ω] == sum(curtailing[:, ω]))
end

# Then variables for the power sent from substation v1 to v2 under scenario ω
# Here we will need to truly linearize the min(power_received by v1, capa_cable(v1, v2)) term 
    