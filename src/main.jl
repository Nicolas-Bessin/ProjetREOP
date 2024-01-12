include("parser.jl")
include("linearSolverCode.jl")
include("utils.jl")
include("costCompute.jl")
include("agregator.jl")

size = "small"
aggregationMethod = "onlyFurthestSites+ninetyPercentWorse"
subLocAgregator = onlyFurthestSites
scenarioAgregator = ninetyPercentWorseScenario

trueInstanceFile = "instances/KIRO-$size.json"
outputFile = "solutions/aggregated/$aggregationMethod-$size.json"

trueInstance = read_instance(trueInstanceFile)
instance = scenarioAgregator(subLocAgregator(trueInstance))
write_instance(instance, "instances/aggregated/$aggregationMethod-$size.json")

solution, time = linearSolver(instance)
trueSolution = deAggregateReducedSiteSolution(trueInstance, instance, solution)
writeSolution(trueSolution, outputFile)
figure = plotSolution(trueSolution, trueInstance)
save("plots/$aggregationMethod-$size.png", figure)

falseCost = costOfSolution(instance, solution)
cost = costOfSolution(trueInstance, trueSolution)

appendCostToFile("solutions/costs.json", cost, aggregationMethod, size, time)