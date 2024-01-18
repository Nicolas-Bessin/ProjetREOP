include("parser.jl")
include("linearRelaxation.jl")

#PARMETERS TO CHANGE#
# Example : for small, onlyFurthestSites+ninetyFivePercentWorse agregations, use :
# size = "small"
# aggregationMethod = "onlyFurthestSites+ninetyFivePercentWorse"
#####################
# To use the original instance && compute the full MILP, use :
#aggregationMethod = ""
size = "large"
#####################

import KIRO2023

trueInstanceFile = "instances/KIRO-$size.json"

outputFormat = "$size-relaxation"

trueInstance = read_instance(trueInstanceFile)

# CHANGE THIS LINE TO CHANGE THE AGGREGATION METHOD #
# Example : for small, onlyFurthestSites+ninetyFivePercentWorse agregations, use :
# instance = xPercentWorseScenario(onlyFurthestSites(trueInstance), 0.95)
#####################################################
# To use the original instance && compute the full MILP, use :
instance = trueInstance
#NOTA BENE : those agregation do not commute, so the order matters
#This because taking the lowest cost cables among the highest probability cables
#is not the same as taking the highest probability cables among the lowest cost cables
# For the no sub sub, no agregation is needed, the absence of sub sub cables is considered in the solve
#####################################################

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
# To use the solver without sub sub cables, use :
# solution, time = linearSolverNoSubSub(instance, rawDataDump)
#################################################
solution, time, consCost, opeCost, totCost = linearRelaxation(instance, rawDataDump)

# CHANGE THIS LINE IF USING A METHOD THAT REQUIRES DE-AGGREGATION #
# Example : for small, onlyFurthestSites+ninetyFivePercentWorse agregations, use :
# trueSolution = deAggregateReducedSiteSolution(trueInstance, instance, solution)
###################################################################
# To use the original instance && compute the full MILP, use :

###################################################################

cost = ( consCost, opeCost, totCost )

print("Self computed cost: $cost\n")

appendCostToFile("solutions/costs.json", cost, outputFormat, time)
