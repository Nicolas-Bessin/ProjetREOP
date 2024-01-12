include("parser.jl")
include("linearSolverCode.jl")
include("utils.jl")
include("costCompute.jl")
include("agregator.jl")

# Optimal value for linear : 3.181693050869e+04
# Optimal value for mean scenario : 3.111073854492e+04

size = "small"
aggregationMethod = "onlyFurthestSites"
aggrFunction = onlyFurthestSites

trueInstanceFile = "instances/KIRO-$size.json"
outputFile = "solutions/aggregated/KIRO-$aggregationMethod-$size.json"

trueInstance = read_instance(trueInstanceFile)
instance = aggrFunction(trueInstance)

solution = linearSolver(instance)
trueSolution = deAggregateReducedSiteSolution(trueInstance, instance, solution)
writeSolution(trueSolution, outputFile)
figure = plotSolution(trueSolution, trueInstance)
save("plots/instance-$size-$aggregationMethod.png", figure)

falseCost = costOfSolution(instance, solution)
cost = costOfSolution(trueInstance, trueSolution)