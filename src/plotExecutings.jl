include("instance.jl")
include("solution.jl")
include("parser.jl")
include("utils.jl")

size = "medium"
outputFormat = "onlyFurthestSites+ninetyFivePercentWorse"
inputFile = "instances/KIRO-$size.json"
solutionFile = "solutions/$size-$outputFormat.json"
instance = read_instance(inputFile)
solution = read_solution(solutionFile)
plotUsedTypes(instance, solution)
