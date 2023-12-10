include("parser.jl")
size = "tiny"
input = "instances/KIRO-$size.json"
output = "solutions/KIRO-$(size)_sol1.json"

instance = read_instance(input) :: Instance

using JuMP, HiGHS

model = Model(HiGHS.Optimizer)

# Add xᵥₛ variables
nbSubLocations = length(instance.substationLocations)
nbSubTypes = length(instance.substationTypes)
@variable(model, x[1:nbSubLocations, 1:nbSubLocations], Bin)

# Add the constraints on substation locations.
for i in 1:nbSubLocations
    @constraint(model, sum(x[i, :]) <= 1)
end
