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

function worstCaseScenario(instance :: Instance)
    # We take the worst case scenario - that is we return an instance with only one scenario, the worst one
    worstPower = sort(instance.windScenarios, by = x -> x.power)[end].power
    worstScenario = WindScenario(1, worstPower, 1.0)
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
        [worstScenario],
        instance.windTurbine,
    )

    
end

function xPercentWorseScenario(instance :: Instance, x :: Float64)
    sortedScenarios = sort(instance.windScenarios, by = x -> x.power)
    minPower = sortedScenarios[1].power
    maxPower = sortedScenarios[end].power
    xPercentWorsePower = minPower + x * (maxPower - minPower)
    xPercentWorseScenario = WindScenario(1, xPercentWorsePower, 1.0)
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
        [xPercentWorseScenario],
        instance.windTurbine,
    )
end

function onlyFurthestSites(instance :: Instance, nbCoordinates :: Int64 = 1)
    # We only keep the substation sites closest to the turbines
    # All the instances have the turbines in X > 0, furthest away from the main substation (in X = 0)
    Xpos = unique([site.x for site in instance.substationLocations])
    sort!(Xpos, rev = true)
    kept_locations = [site for site in instance.substationLocations if site.x in Xpos[1:nbCoordinates]]
    locations = [
        Location(
            i,
            site.x,
            site.y)
        for (i, site) in enumerate(kept_locations)
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
        locations,
        instance.substationTypes,
        instance.windScenarios,
        instance.windTurbine,
    )
end

function deAggregateReducedSiteSolution(trueInstance :: Instance, aggregInstance :: Instance, solution :: Solution)
    # We need to find the true substation locations from the aggregated instance (because the ids are different)
    # We compute a dictionnary to associate each substation id in the aggregated instance to the id in the true instance
    idCorrespondance = Dict()
    for siteInAggregatedInstance in aggregInstance.substationLocations
        indexInTrueInstance = findfirst(
            site -> site.x == siteInAggregatedInstance.x && site.y == siteInAggregatedInstance.y,
            trueInstance.substationLocations
        )
        idCorrespondance[siteInAggregatedInstance.id] = trueInstance.substationLocations[indexInTrueInstance].id
    end
    # Change the ids in the substations objects of the solution to reflect the true ids in the initial instance
    trueSubstations = [
        Substation(
            idCorrespondance[substation.id_loc],
            substation.id_type,
            substation.id_cable
        )
        for substation in solution.substations
    ]
    # Change the ids in the cables objects of the solution to reflect the true ids in the initial instance
    trueCables = [
        Cable(
            cable.id_type,
            idCorrespondance[cable.id_sub1],
            idCorrespondance[cable.id_sub2]
        )
        for cable in solution.cables
    ]
    # Change the ids in the turbines objects of the solution to reflect the true ids in the initial instance
    trueTurbines = [
        WindTurbine(
            turbine.id_loc,
            idCorrespondance[turbine.id_sub]
        )
        for turbine in solution.windTurbines
    ]
    return Solution(trueSubstations, trueCables, trueTurbines)
end

function onlyHighestProbaSubs(instance :: Instance, nbSubs :: Int64 = 1)
    # We only keep the substations with the highest probability of failure
    # (Because they are the lowest cost ones)
    # This comes from the fact that for small & medium, the solution only uses the substations with the highest probability of failure
    failure_probas = sort([sub.probability_failure for sub in instance.substationTypes], rev = true)
    kept_substations = [sub for sub in instance.substationTypes if sub.probability_failure in failure_probas[1:nbSubs]]
    substations = [
        SubstationType(
            i,
            sub.cost,
            sub.rating,
            sub.probability_failure)
        for (i, sub) in enumerate(kept_substations)
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
        substations,
        instance.windScenarios,
        instance.windTurbine,
    )

end

function onlyLowerCostSubTypes(instance :: Instance, nbSubs :: Int64 = 4)
    # We only keep the substations with cost in the three lowest costs
    # Because this is empirically what happens in the solutions for small & medium
    costs = [sub.cost for sub in instance.substationTypes]
    sorted_costs = sort(costs)
    kept_substations = [sub for sub in instance.substationTypes if sub.cost in sorted_costs[1:nbSubs]]
    substations = [
        SubstationType(
            i,
            sub.cost,
            sub.rating,
            sub.probability_failure)
        for (i, sub) in enumerate(kept_substations)
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
        substations,
        instance.windScenarios,
        instance.windTurbine,
    )
end

function deAggregateReducedSubstationTypes(trueInstance :: Instance, instance :: Instance, solution :: Solution)
    # We only need one de-agregator for every agregator for substation types
    # Because we don't change the ratings & probabilities of failure of the substations in the modified instances
    # We need to find the true substation types from the aggregated instance (because the ids are different)
    # We compute a dictionnary to associate each substation id in the aggregated instance to the id in the true instance
    idCorrespondance = Dict()
    for subInAggregatedInstance in instance.substationTypes
        indexInTrueInstance = findfirst(
            sub -> sub.rating == subInAggregatedInstance.rating && sub.probability_failure == subInAggregatedInstance.probability_failure,
            trueInstance.substationTypes
        )
        idCorrespondance[subInAggregatedInstance.id] = trueInstance.substationTypes[indexInTrueInstance].id
    end

    trueSubstations = [
        Substation(
            substation.id_loc,
            idCorrespondance[substation.id_type],
            substation.id_cable
        )
        for substation in solution.substations
    ]

    return Solution(trueSubstations, solution.cables, solution.windTurbines)
end

function onlyHighestProbaLandCables(instance :: Instance, nbCables :: Int64 = 1)
    # We only keep the cables with the highest probability of failure
    # (Because they are the lowest cost ones)
    # This comes from the fact that for small & medium, the solution only uses the cables with the highest probability of failure
    failure_probas = sort([cable.probability_failure for cable in instance.landSubstationCables], rev = true)
    kept_cables = [cable for cable in instance.landSubstationCables if cable.probability_failure in failure_probas[1:nbCables]]
    cables = [
        CableType(
            i,
            cable.fixed_cost,
            cable.variable_cost,
            cable.rating,
            cable.probability_failure)
        for (i, cable) in enumerate(kept_cables)
    ]
    return Instance(
        instance.curtailingCost,
        instance.curtailingPenalty,
        instance.maxCurtailment,
        instance.fixedCostCable,
        instance.variableCostCable,
        instance.mainLandSubstation,
        instance.maximumPower,
        cables,
        instance.substationSubstationCables,
        instance.substationLocations,
        instance.substationTypes,
        instance.windScenarios,
        instance.windTurbine,
    )
end

function onlyLowerCostLandCables(instance :: Instance, nbCables :: Int64 = 4)
    # We only keep the cables with cost in the three lowest costs
    # Because this is empirically what happens in the solutions for small & medium
    costs = [cable.variable_cost for cable in instance.landSubstationCables]
    sorted_costs = sort(costs)
    kept_cables = [cable for cable in instance.landSubstationCables if cable.variable_cost in sorted_costs[1:nbCables]]
    cables = [
        CableType(
            i,
            cable.fixed_cost,
            cable.variable_cost,
            cable.rating,
            cable.probability_failure)
        for (i, cable) in enumerate(kept_cables)
    ]
    return Instance(
        instance.curtailingCost,
        instance.curtailingPenalty,
        instance.maxCurtailment,
        instance.fixedCostCable,
        instance.variableCostCable,
        instance.mainLandSubstation,
        instance.maximumPower,
        cables,
        instance.substationSubstationCables,
        instance.substationLocations,
        instance.substationTypes,
        instance.windScenarios,
        instance.windTurbine,
    )
end

function deAggregateReducedLandCables(trueInstance :: Instance, instance :: Instance, solution :: Solution)
    # We only need one de-agregator for every agregator for land cables
    # Because we don't change the ratings & probabilities of failure of the cables in the modified instances
    # We need to find the true cable types from the aggregated instance (because the ids are different)
    # We compute a dictionnary to associate each cable id in the aggregated instance to the id in the true instance
    idCorrespondance = Dict()
    for cableInAggregatedInstance in instance.landSubstationCables
        indexInTrueInstance = findfirst(
            cable -> cable.rating == cableInAggregatedInstance.rating && cable.probability_failure == cableInAggregatedInstance.probability_failure,
            trueInstance.landSubstationCables
        )
        idCorrespondance[cableInAggregatedInstance.id] = trueInstance.landSubstationCables[indexInTrueInstance].id
    end

    trueSubstations = [
        Substation(
            substation.id_loc,
            substation.id_type,
            idCorrespondance[substation.id_cable]
        )
        for substation in solution.substations
    ]

    return Solution(trueSubstations, solution.cables, solution.windTurbines)
end

function noSubSubCables(instance :: Instance)
    # We remove the substation - substation cables
    return Instance(
        instance.curtailingCost,
        instance.curtailingPenalty,
        instance.maxCurtailment,
        instance.fixedCostCable,
        instance.variableCostCable,
        instance.mainLandSubstation,
        instance.maximumPower,
        instance.landSubstationCables,
        [],
        instance.substationLocations,
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

# aggregateInstances("instances/aggregated/onlyFurthestSites", onlyFurthestSites)

