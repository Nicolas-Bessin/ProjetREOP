include("parser.jl")
include("linearSolverCode.jl")
#include("solverConstructionCost.jl")
#include("solverQuadraticIndicator.jl")
#include("solverNoSubSub.jl")
#include("utils.jl")
include("costCompute.jl")
include("agregator.jl")

#PARMETERS TO CHANGE#
# Example : for small, onlyFurthestSites+ninetyFivePercentWorse agregations, use :
# size = "small"
# aggregationMethod = "onlyFurthestSites+ninetyFivePercentWorse"
#####################
# To use the original instance && compute the full MILP, use :
#aggregationMethod = ""
size = "medium"
aggregationMethod = "testing"
#####################

import KIRO2023

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
#instance = trueInstance
#NOTA BENE : those agregation do not commute, so the order matters
#This because taking the lowest cost cables among the highest probability cables
#is not the same as taking the highest probability cables among the lowest cost cables
# For the no sub sub, no agregation is needed, the absence of sub sub cables is considered in the solver
choiceColumns = 1:2
choiceProbaCables = 1:3
choiceCostCables = 1:12
choiceProbaSubs = 1:3
choiceCostSubs = 1:12
instance = 
onlyLowerCostSubTypes(
    onlyLowerCostLandCables(
        onlyHighestProbaSubs(
            onlyHighestProbaLandCables(
                onlyFurthestSites(
                    (
                        (
                            xPercentWorseScenario(trueInstance, 0.99)
                        )
                    )
                , choiceColumns)
            , choiceProbaCables)
        , choiceProbaSubs)
    , choiceCostCables)
, choiceCostSubs)

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
# To use the solver without sub sub cables, use :
# solution, time = linearSolverNoSubSub(instance, rawDataDump)
#################################################
solution, time = linearSolver(instance, rawDataDump)

# CHANGE THIS LINE IF USING A METHOD THAT REQUIRES DE-AGGREGATION #
# Example : for small, onlyFurthestSites+ninetyFivePercentWorse agregations, use :
# trueSolution = deAggregateReducedSiteSolution(trueInstance, instance, solution)
###################################################################
# To use the original instance && compute the full MILP, use :
#trueSolution = solution
trueSolution = deAggregateReducedSiteSolution(trueInstance, instance, 
    deAggregateReducedSubstationTypes(trueInstance, instance, 
        deAggregateReducedLandCables(trueInstance, instance, solution)
        )
    )

#trueSolution = solution

###################################################################

writeSolution(trueSolution, "solutions/$outputFormat.json")
#figure = plotSolution(trueSolution, trueInstance)
#save("plots/plots/$outputFormat.png", figure)

#figure = plotUsedTypes(trueInstance, trueSolution, instance)
#save("plots/types/$outputFormat.png", figure)

falseCost = costOfSolution(instance, solution)
cost = costOfSolution(trueInstance, trueSolution)
print("Self computed cost: $cost\n")

offInstance = KIRO2023.read_instance("instances/KIRO-$size.json")
offSolution = KIRO2023.read_solution("solutions/$outputFormat.json", offInstance)
officialCost = (
    KIRO2023.construction_cost(offSolution, offInstance),
    KIRO2023.operational_cost(offSolution, offInstance),
    KIRO2023.cost(offSolution, offInstance)
)


print("Official cost: $officialCost\n")

pathToBestSolsFiles = "solutions/bestSols/cost-bests.json"

bestCosts = JSON.parsefile(pathToBestSolsFiles)
if bestCosts[size]["total"] > officialCost[3]
    println("--------------------------------------------")
    println("New best solution found for $size")
    bestCosts[size]["construction"] = officialCost[1]
    bestCosts[size]["operational"] = officialCost[2]
    bestCosts[size]["total"] = officialCost[3]
    bestCosts[size]["time"] = time
    open(pathToBestSolsFiles, "w") do f
        JSON.print(f, bestCosts, 4)
    end

    writeSolution(trueSolution, "solutions/bestSols/$size-best.json")
end

appendCostToFile("solutions/costs.json", cost, outputFormat, time)
