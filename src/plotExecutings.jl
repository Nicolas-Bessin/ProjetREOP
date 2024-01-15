include("instance.jl")
include("solution.jl")
include("parser.jl")
include("utils.jl")

size = "huge"
outputFormat = "1"
inputFile = "instances/KIRO-$size.json"
reducedInput = "instances/aggregated/$size-$outputFormat.json"
solutionFile = "solutions/$size-$outputFormat.json"
instance = read_instance(inputFile)
reducedInstance = instance
solution = read_solution(solutionFile)
plotUsedTypes(instance, reducedInstance, solution)
plotSolution(solution, instance)
