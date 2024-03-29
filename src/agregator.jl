# In this file, we try to aggregate the instances into almost equivalent - but smaller instances
# For example, regrouping the power scenario into a mean scenario.

include("parser.jl")
include("instance.jl")

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

function nWorseScenario(instance :: Instance, n :: Int = 5)
    scenarios = sort(instance.windScenarios, by = x-> x.power, rev = true)
    normalization = sum([scenario.probability for scenario in scenarios[1:n]])
    kept_scenarios = [
        WindScenario(
            i,
            scenario.power,
            scenario.probability / normalization
        ) for (i, scenario) in enumerate(scenarios[1:n])
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
        kept_scenarios,
        instance.windTurbine,
    )
end

function onlyFurthestSites(instance :: Instance, columns = [])
    if columns == []
        columns = 1:length(unique([site.x for site in instance.substationLocations]))
    end
    # We only keep the substation sites closest to the turbines
    # All the instances have the turbines in X > 0, furthest away from the main substation (in X = 0)
    Xpos = unique([site.x for site in instance.substationLocations])
    sort!(Xpos, rev = true)
    kept_locations = [site for site in instance.substationLocations if site.x in Xpos[columns]]
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

function onlyHighestProbaSubs(instance :: Instance, highest = [])
    if highest == []
        highest = 1:length(unique([sub.probability_failure for sub in instance.substationTypes]))
    end
    # We only keep the substations with the highest probability of failure
    # (Because they are the lowest cost ones)
    # This comes from the fact that for small & medium, the solution only uses the substations with the highest probability of failure
    probas = unique(sort([sub.probability_failure for sub in instance.substationTypes], rev = true))
    kept_substations = [sub for sub in instance.substationTypes if sub.probability_failure in probas[highest]]
    newSubstations = [
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
        newSubstations,
        instance.windScenarios,
        instance.windTurbine,
    )

end

function onlyLowerCostSubTypes(instance :: Instance, lowest = [])
    if lowest == []
        lowest = 1:length(unique([sub.cost for sub in instance.substationTypes]))
    end
    # We only keep the substations with cost in the three lowest costs
    # Because this is empirically what happens in the solutions for small & medium
    costs = unique(sort([sub.cost for sub in instance.substationTypes]))
    kept_substations = [sub for sub in instance.substationTypes if sub.cost in costs[lowest]]
    newSubstations = [
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
        newSubstations,
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

function onlyHighestProbaLandCables(instance :: Instance, highest = [])
    if highest == []
        highest = 1:length(unique([cable.probability_failure for cable in instance.landSubstationCables]))
    end
    # We only keep the cables with the highest probability of failure
    # (Because they are the lowest cost ones)
    # This comes from the fact that for small & medium, the solution only uses the cables with the highest probability of failure
    probas = unique(sort([cable.probability_failure for cable in instance.landSubstationCables], rev = true))
    kept_cables = [cable for cable in instance.landSubstationCables if cable.probability_failure in probas[highest]]
    newCables = [
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
        newCables,
        instance.substationSubstationCables,
        instance.substationLocations,
        instance.substationTypes,
        instance.windScenarios,
        instance.windTurbine,
    )
end

function onlyLowerCostLandCables(instance :: Instance, lowest = [])
    if lowest == []
        lowest = 1:length(unique([cable.variable_cost for cable in instance.landSubstationCables]))
    end
    # We only keep the cables with cost in the three lowest costs
    # Because this is empirically what happens in the solutions for small & medium
    varCosts = unique(sort([cable.variable_cost for cable in instance.landSubstationCables]))
    kept_cables = [cable for cable in instance.landSubstationCables if cable.variable_cost in varCosts[lowest]]
    newCables = [
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
        newCables,
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

function DummySubSubCables(instance :: Instance)
    # We remove the substation - substation cables and replace them with a dummy cable type
    return Instance(
        instance.curtailingCost,
        instance.curtailingPenalty,
        instance.maxCurtailment,
        instance.fixedCostCable,
        instance.variableCostCable,
        instance.mainLandSubstation,
        instance.maximumPower,
        instance.landSubstationCables,
        [CableType(1, 100, 100, 0.0, 0.0)],
        instance.substationLocations,
        instance.substationTypes,
        instance.windScenarios,
        instance.windTurbine,
    )
end

function TurbineAgregator(instance :: Instance)
    # We aggregate the turbines by rows (i.e. by Y coordinate)
    # This works because each the same number of turbines in each row (i.e. each Y coordinate)
    # To compensate, we multiply the power of each scenario by the number of turbines in each row
    # We also multiply the fixed and variable costs of the cables by the number of turbines in each row
    # Because each turbine in the new instance represents a row of turbines in the original instance,
    # Meaning there are numberByRow more cables in the true solution than in the reduced solution

    Ycoords = unique([turbine.y for turbine in instance.windTurbine])
    Xcoords = unique([turbine.x for turbine in instance.windTurbine])
    numberByRow = length(Xcoords)
    meanX = sum(Xcoords) / numberByRow
    scenarios = [
        WindScenario(
            scenario.id,
            scenario.power * numberByRow,
            scenario.probability
        )
        for scenario in instance.windScenarios
    ]
    turbines = [
        Location(
            i,
            meanX,
            Y
        ) for (i, Y) in enumerate(Ycoords)
    ]
    return Instance(
        instance.curtailingCost,
        instance.curtailingPenalty,
        instance.maxCurtailment,
        instance.fixedCostCable * numberByRow,
        instance.variableCostCable * numberByRow,
        instance.mainLandSubstation,
        instance.maximumPower * numberByRow,
        instance.landSubstationCables,
        instance.substationSubstationCables,
        instance.substationLocations,
        instance.substationTypes,
        scenarios,
        turbines,
    )

end

function deAggregateReducedTurbines(trueInstance :: Instance, instance :: Instance, solution :: Solution)
    # We de-aggregate the turbines by rows (i.e. by Y coordinate)
    # For each turbine in the original instance, we find the turbine in the reduced instance with the same Y coordinate
    # We then link the turbine in the original instance to the same substation as the turbine in the reduced instance
    
    # We first compute a dictionnary to associate each turbine Y coordinate to the id of the substation it is linked to
    SubIdCorrespondance = Dict()
    for turbine in solution.windTurbines
        SubIdCorrespondance[instance.windTurbine[turbine.id_loc].y] = turbine.id_sub
    end

    # We then create the turbines in the true solution
    trueTurbines = [
        WindTurbine(
            turbine.id,
            SubIdCorrespondance[turbine.y]
        )
        for turbine in trueInstance.windTurbine
    ]

    return Solution(solution.substations, solution.cables, trueTurbines)

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

