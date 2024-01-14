include("instance.jl")
include("solution.jl")
include("parser.jl")
include("utils.jl")

size = "large"
outputFormat = "FurthestSites+95%Worse+SubTypes&LandCablesHighProba&LowCost+DummySubSub+Turbines"
inputFile = "instances/KIRO-$size.json"
reducedInput = "instances/aggregated/$size-$outputFormat.json"
solutionFile = "solutions/$size-$outputFormat.json"
instance = read_instance(inputFile)
reducedInstance = read_instance(reducedInput)
solution = read_solution(solutionFile)
plotUsedTypes(instance, reducedInstance, solution)
