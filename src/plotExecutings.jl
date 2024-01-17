include("instance.jl")
include("solution.jl")
include("parser.jl")
include("utils.jl")
include("agregator.jl")

size = "small"

aggregationMethod = ""
if aggregationMethod == ""
    outputFormat = "$size"
else
    outputFormat = "$size-$aggregationMethod"
end

inputFile = "instances/KIRO-$size.json"
reducedInput = "instances/aggregated/$outputFormat.json"
solutionFile = "solutions/$outputFormat.json"
instance = read_instance(inputFile)
if outputFormat != "1" && outputFormat != ""
    reducedInstance = read_instance(reducedInput)
else
    reducedInstance = instance
end
solution = read_solution(solutionFile)
f = plotUsedTypes(instance, solution, (800, 400))
save("plots/types/$outputFormat-types.png", f)
f = plotSolution(solution, instance)
save("plots/plots/$outputFormat.png", f)
