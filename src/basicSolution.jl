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