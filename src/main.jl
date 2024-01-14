include("parser.jl")
include("linearSolverCode.jl")
include("solverQuadraticIndicator.jl")
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
size = "medium"
aggregationMethod = "onlyFurthestSites+worstCaseScenario"
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
instance = worstCaseScenario(onlyFurthestSites(trueInstance))
#####################################################

if aggregationMethod != ""
    write_instance(instance, "instances/aggregated/$outputFormat.json")
end 

# Raw data dump file for the MILP
# If you don't want to save the raw data, just set rawDataDump to ""
# Example : rawDataDump = "solutions/rawData/$outputFormat.json"
rawDataDump = ""
# Add the raw data dump filename if you want to save the raw data

# CHANGE THIS LINE TO CHANGE THE SOLVER METHOD #
# To use the quadratic solver, use :
# solution, time = linearQuadraticSolver(instance, rawDataDump)
# To use the pure linear solver, use :
# solution, time = linearSolver(instance, rawDataDump)
#################################################
solution, time = linearSolver(instance, rawDataDump)

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
