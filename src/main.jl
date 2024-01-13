include("parser.jl")
include("linearSolverCode.jl")
include("utils.jl")
include("costCompute.jl")
include("agregator.jl")

#PARMETERS TO CHANGE#
# Example : for small, onlyFurthestSites+ninetyFivePercentWorse agregations, use :
# size = "small"
# aggregationMethod = "onlyFurthestSites+ninetyFivePercentWorse"
#####################
# To use the original instance && compute the full MILP, use :
# aggregationMethod = ""
size = "large"
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
# Example : for small, onlyFurthestSites+ninetyFivePercentWorse agregations, use :
# instance = xPercentWorseScenario(onlyFurthestSites(trueInstance), 0.95)
#####################################################
# To use the original instance && compute the full MILP, use :
# instance = trueInstance
instance = xPercentWorseScenario(onlyFurthestSites(trueInstance), 0.95)
#####################################################

if aggregationMethod != ""
    write_instance(instance, "instances/aggregated/$outputFormat.json")
end 

solution, time = linearSolver(instance)

# CHANGE THIS LINE IF USING A METHOD THAT REQUIRES DE-AGGREGATION #
# Example : for small, onlyFurthestSites+ninetyFivePercentWorse agregations, use :
# trueSolution = deAggregateReducedSiteSolution(trueInstance, instance, solution)
###################################################################
# To use the original instance && compute the full MILP, use :
# trueSolution = solution
trueSolution = deAggregateReducedSiteSolution(trueInstance, instance, solution)
###################################################################

writeSolution(trueSolution, "solutions/$outputFormat.json")
figure = plotSolution(trueSolution, trueInstance)
save("plots/$outputFormat.png", figure)

falseCost = costOfSolution(instance, solution)
cost = costOfSolution(trueInstance, trueSolution)

appendCostToFile("solutions/costs.json", cost, outputFormat, time)