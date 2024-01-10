# In this file, we try to aggregate the instances into almost equivalent - but smaller instances
# For example, regrouping the power scenario into a mean scenario.

include("parser.jl")
include("instance.jl")

sizes = ["tiny", "small", "medium", "large", "huge"]

function meanPowerScenario(instance :: Instance)
    meanPower = sum([w.power * w.probability for w in instance.windScenarios])
    meanScenario = WindScenario(1, meanPower, 1.0)
    return Instance(
        instance.curtailingCost,
        instance.curtailingPenalty,
        instance.maxCurtailment,
        instance.fixedCostCable,
        instance.variableCostCable,
        instance.mainLandSubstation,
        meanPower,
        instance.landSubstationCables,
        instance.substationSubstationCables,
        instance.substationLocations,
        instance.substationTypes,
        [meanScenario],
        instance.windTurbine,
    )
end

function aggregateInstances(outputFormat :: String, aggregationFunction :: Function)
    for size in sizes
        inputFile = "instances/KIRO-$size.json"
        originalInstance = read_instance(inputFile)
        newInstance = aggregationFunction(originalInstance)
        write_instance(newInstance, outputFormat * "-$size.json")
    end
end

aggregateInstances("instances/aggregated/KIRO-mean", meanPowerScenario)