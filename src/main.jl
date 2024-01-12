include("parser.jl")
include("linearSolverCode.jl")
include("utils.jl")
include("costCompute.jl")
include("agregator.jl")

#PARMETERS TO CHANGE#
# Example :
# size = "small"
# aggregationMethod = "onlyFurthestSites+ninetyFivePercentWorse"
size = "medium"
aggregationMethod = "onlyFurthestSites+ninetyFivePercentWorse"
#####################

trueInstanceFile = "instances/KIRO-$size.json"

if aggregationMethod == ""
    outputFormat = "$size"
else
    outputFormat = "$size-$aggregationMethod"
end

trueInstance = read_instance(trueInstanceFile)

# CHANGE THIS LINE TO CHANGE THE AGGREGATION METHOD #
# Example :
# instance = xPercentWorseScenario(onlyFurthestSites(trueInstance), 0.95)
instance = xPercentWorseScenario(onlyFurthestSites(trueInstance), 0.95)
#####################################################

if aggregationMethod != ""
    write_instance(instance, "instances/aggregated/$outputFormat.json")
end 

solution, time = linearSolver(instance)

# CHANGE THIS LINE IF USING A METHOD THAT REQUIRES DE-AGGREGATION #
# Example :
# trueSolution = deAggregateReducedSiteSolution(trueInstance, instance, solution)
trueSolution = deAggregateReducedSiteSolution(trueInstance, instance, solution)
###################################################################

writeSolution(trueSolution, "solutions/$outputFormat.json")
figure = plotSolution(trueSolution, trueInstance)
save("plots/$outputFormat.png", figure)

falseCost = costOfSolution(instance, solution)
cost = costOfSolution(trueInstance, trueSolution)

appendCostToFile("solutions/costs.json", cost, aggregationMethod, size, time)