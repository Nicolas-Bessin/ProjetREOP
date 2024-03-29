include("solution.jl")
include("instance.jl")

maxCurtailmentExceeded = false

function constructionCost(instance::Instance, solution::Solution)
    cost = 0.
    # We first add the construction cost for the substations
    for substation in solution.substations
        cost += instance.substationTypes[substation.id_type].cost
    end
    # Then we add the constuction cost for the land-sub cables
    for substation in solution.substations
        length = distance(instance.mainLandSubstation, instance.substationLocations[substation.id_loc])
        cost += length * instance.landSubstationCables[substation.id_cable].variable_cost
        cost += instance.landSubstationCables[substation.id_cable].fixed_cost
    end
    # Then we add the construction cost for the sub-sub cables
    for cable in solution.cables
        length = distance(instance.substationLocations[cable.id_sub1], instance.substationLocations[cable.id_sub2])
        cost += length * instance.substationSubstationCables[cable.id_type].variable_cost
        cost += instance.substationSubstationCables[cable.id_type].fixed_cost
    end
    # Then we add the construction cost for the wind turbines cables
    for turbine in solution.windTurbines
        length = distance(instance.substationLocations[turbine.id_sub], instance.windTurbine[turbine.id_loc])
        cost += length * instance.variableCostCable
        cost += instance.fixedCostCable
    end

    return cost
end

function noFailureCurtailing(instance :: Instance, solution :: Solution, power :: Float64)
    curtailing = 0.
    for substation in solution.substations
        nbTurbines = sum([ 1 for turbine in solution.windTurbines if turbine.id_sub == substation.id_loc ])
        capacity = min(
            instance.substationTypes[substation.id_type].rating,
            instance.landSubstationCables[substation.id_cable].rating
        )
        curtailing += max(0, power * nbTurbines - capacity)
    end

    return curtailing
end

function curtailingUnderOwnFailure(instance :: Instance, solution :: Solution, substation :: Substation, power :: Float64)
    curtailing = 0.
    nbTurbines = sum([ 1 for turbine in solution.windTurbines if turbine.id_sub == substation.id_loc ])
    curtailing = power * nbTurbines
    # Find a cable that is connected to the substation, if applicable
    connected_cable = nothing
    for cable in solution.cables
        if cable.id_sub1 == substation.id_loc || cable.id_sub2 == substation.id_loc
            connected_cable = cable
            break
        end
    end
    if !(isnothing(connected_cable))
        capacity = instance.substationSubstationCables[connected_cable.id_type].rating
        curtailing -= capacity
    end

    return max(0, curtailing)
end

function curtailinUnderOtherFailure(instance :: Instance, solution :: Solution, substation :: Substation, failedSub :: Substation, power :: Float64)
    curtailing = 0.
    nbTurbines = sum([ 1 for turbine in solution.windTurbines if turbine.id_sub == substation.id_loc ])
    # Find a cable from the failed_substation to this substation, if applicable
    connected_cable = nothing
    for cable in solution.cables
        if (cable.id_sub1 == substation.id_loc && cable.id_sub2 == failedSub.id_loc) 
            connected_cable = cable
            break
        end
        #Broken up for readability
        if (cable.id_sub1 == failedSub.id_loc && cable.id_sub2 == substation.id_loc) 
            connected_cable = cable
            break
        end
    end
    power_received = 0.
    if !(isnothing(connected_cable))
        nbTurbinesFailed = sum([ 1 for turbine in solution.windTurbines if turbine.id_sub == failedSub.id_loc ])
        capaSubSubCable = instance.substationSubstationCables[connected_cable.id_type].rating
        power_received = min(capaSubSubCable, power * nbTurbinesFailed)
    end
    # Capacity of the cable from this substation to the ground
    capaSubLandCable = instance.landSubstationCables[substation.id_cable].rating
    capaSubstation = instance.substationTypes[substation.id_type].rating
    capacity = min(capaSubLandCable, capaSubstation)
    curtailing = max(0, power * nbTurbines + power_received - capacity)
    return curtailing

end

function totalCurtailingGivenFailedSub(instance :: Instance, solution :: Solution, failedSub :: Substation, power :: Float64)
    curtailing = 0.
    curtailing += curtailingUnderOwnFailure(instance, solution, failedSub, power)
    for substation in solution.substations
        if substation.id_loc != failedSub.id_loc
            curtailing += curtailinUnderOtherFailure(instance, solution, substation, failedSub, power)
        end
    end
    return curtailing
end

function costOfCurtailing(instance :: Instance, curtailing :: Float64)
    if curtailing > instance.maxCurtailment
        maxCurtailmentExceeded = true
    end
    return instance.curtailingCost * curtailing + instance.curtailingPenalty * max(0, curtailing - instance.maxCurtailment)
end

function probFailure(instance :: Instance, substation :: Substation)
    prob = instance.substationTypes[substation.id_type].probability_failure
    prob += instance.landSubstationCables[substation.id_cable].probability_failure
    return prob
end

function operationalCost(instance :: Instance, solution :: Solution)
    cost = 0.
    #Compute the failure probas only once
    failureProbas = Dict()
    for substation in solution.substations
        failureProbas[substation.id_loc] = probFailure(instance, substation)
    end
    noFailProb = 1 - sum(values(failureProbas))
    #Compute the cost
    for scenario in instance.windScenarios
        scenarioCost = 0.
        for substation in solution.substations
            curtailing = totalCurtailingGivenFailedSub(instance, solution, substation, scenario.power)
            scenarioCost += failureProbas[substation.id_loc] * costOfCurtailing(instance, curtailing)
        end
        curtailingNoFailure = noFailureCurtailing(instance, solution, scenario.power)
        scenarioCost += noFailProb * costOfCurtailing(instance, curtailingNoFailure)
        cost += scenario.probability * scenarioCost
    end

    return cost
end

function costOfSolution(instance :: Instance, solution :: Solution)
    conCost = constructionCost(instance, solution)
    opeCost = operationalCost(instance, solution)
    if maxCurtailmentExceeded
        print("WARNING: Maximum curtailment exceeded")
    end
    return (conCost, opeCost, conCost + opeCost)
end