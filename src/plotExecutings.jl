include("instance.jl")
include("solution.jl")
include("parser.jl")
include("utils.jl")
include("agregator.jl")

size = "huge"
outputFormat = "furthestSites+2HProbas+4LCost+Turbines+NoSSCables+95Worse"
inputFile = "instances/KIRO-$size.json"
reducedInput = "instances/aggregated/$size-$outputFormat.json"
solutionFile = "solutions/$size-$outputFormat.json"
instance = read_instance(inputFile)
if outputFormat != "1"
    reducedInstance = read_instance(reducedInput)
else
    reducedInstance = instance
end
solution = read_solution(solutionFile)
f = plotUsedTypes(instance, reducedInstance, solution)
save("plots/types/$size-$outputFormat.png", f)
#plotSolution(solution, instance)
