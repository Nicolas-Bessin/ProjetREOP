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
        instance.maximumPower,
        instance.landSubstationCables,
        instance.substationSubstationCables,
        instance.substationLocations,
        instance.substationTypes,
        [meanScenario],
        instance.windTurbine,
    )
end

function quartersPowerScenario(instance :: Instance)
    # We split the power into 4 quarters
    powerScenarios = sort(instance.windScenarios, by = x -> x.power)
    n = length(powerScenarios)
    firstQuarter = sum([w.power * w.probability for w in powerScenarios[1:floor(Int, n/4)]])
    secondQuarter = sum([w.power * w.probability for w in powerScenarios[floor(Int, n/4)+1:floor(Int, n/2)]])
    thirdQuarter = sum([w.power * w.probability for w in powerScenarios[floor(Int, n/2)+1:floor(Int, 3*n/4)]])
    fourthQuarter = sum([w.power * w.probability for w in powerScenarios[floor(Int, 3*n/4)+1:n]])
    scenarios = [
        WindScenario(1, firstQuarter, 0.25),
        WindScenario(2, secondQuarter, 0.25),
        WindScenario(3, thirdQuarter, 0.25),
        WindScenario(4, fourthQuarter, 0.25)
    ]
    return Instance(
        instance.curtailingCost,
        instance.curtailingPenalty,
        instance.maxCurtailment,
        instance.fixedCostCable,
        instance.variableCostCable,
        instance.mainLandSubstation,
        instance.maximumPower,
        instance.landSubstationCables,
        instance.substationSubstationCables,
        instance.substationLocations,
        instance.substationTypes,
        scenarios,
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

aggregateInstances("instances/aggregated/KIRO-quarters", quartersPowerScenario)