# In this file, we try to aggregate the instances into almost equivalent - but smaller instances
# For example, regrouping the power scenario into a mean scenario.

include("parser.jl")
include("instance.jl")

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
    firstQuarterWeight = sum([w.probability for w in powerScenarios[1:floor(Int, n/4)]])
    firstQuarter = sum([w.power * w.probability / firstQuarterWeight for w in powerScenarios[1:floor(Int, n/4)]])
    secondQuarterWeight = sum([w.probability for w in powerScenarios[floor(Int, n/4)+1:floor(Int, n/2)]])
    secondQuarter = sum([w.power * w.probability / secondQuarterWeight for w in powerScenarios[floor(Int, n/4)+1:floor(Int, n/2)]])
    thirdQuarterWeight = sum([w.probability for w in powerScenarios[floor(Int, n/2)+1:floor(Int, 3n/4)]])
    thirdQuarter = sum([w.power * w.probability / thirdQuarterWeight for w in powerScenarios[floor(Int, n/2)+1:floor(Int, 3n/4)]])
    fourthQuarterWeight = sum([w.probability for w in powerScenarios[floor(Int, 3n/4)+1:n]])
    fourthQuarter = sum([w.power * w.probability / fourthQuarterWeight for w in powerScenarios[floor(Int, 3n/4)+1:n]])
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

function onlyFurthestSites(instance :: Instance, nbCoordinates :: Int64 = 1)
    # We only keep the substation sites closest to the turbines
    # All the instances have the turbines in X > 0, furthest away from the main substation (in X = 0)
    Xpos = unique([site.x for site in instance.substationLocations])
    sort!(Xpos, rev = true)
    locations = [site for site in instance.substationLocations if site.x in Xpos[1:nbCoordinates]]
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
        locations,
        instance.substationTypes,
        instance.windScenarios,
        instance.windTurbine,
    )
end


function aggregateInstances(outputFormat :: String, aggregationFunction :: Function)
    sizes = ["small", "medium", "large", "huge"]
    for size in sizes
        inputFile = "instances/KIRO-$size.json"
        originalInstance = read_instance(inputFile)
        newInstance = aggregationFunction(originalInstance)
        write_instance(newInstance, outputFormat * "-$size.json")
    end
end

function idem(instance :: Instance)
    return instance
end

aggregateInstances("instances/aggregated/onlyFurthestSites", onlyFurthestSites)

