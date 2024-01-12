include("parser.jl")
include("linearSolverCode.jl")
include("utils.jl")
include("costCompute.jl")
include("agregator.jl")

size = "large"
aggregationMethod = "onlyFurthestSites+worstCaseScenario"
subLocAgregator = onlyFurthestSites
scenarioAgregator = worstCaseScenario

trueInstanceFile = "instances/KIRO-$size.json"
outputFile = "solutions/aggregated/KIRO-$aggregationMethod-$size.json"

trueInstance = read_instance(trueInstanceFile)
instance = scenarioAgregator(subLocAgregator(trueInstance))
write_instance(instance, "instances/aggregated/KIRO-$aggregationMethod-$size.json")

solution = linearSolver(instance)
trueSolution = deAggregateReducedSiteSolution(trueInstance, instance, solution)
writeSolution(trueSolution, outputFile)
figure = plotSolution(trueSolution, trueInstance)
save("pltots/$aggregationMethod-$size.png", figure)

falseCost = costOfSolution(instance, solution)
cost = costOfSolution(trueInstance, trueSolution)

appendCostToFile("solutions/costs.json", cost, aggregationMethod, size)