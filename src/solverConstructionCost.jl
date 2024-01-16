include("instance.jl")
include("solution.jl")

using JuMP, Gurobi, JSON

function solverConstructionCost(instance :: Instance,  filename :: String = "")
    # We need to compute an upper bound for the curtailing cost under failure (At first we can compute one for every scenario)
    nbScenarios = length(instance.windScenarios)
    # Maximum power produced by ONE turbine
    max_power = maximum([instance.windScenarios[i].power for i in 1:nbScenarios]) 
    max_overall_power = max_power * length(instance.windTurbine)
    max_cost = instance.curtailingCost * max_power + instance.curtailingPenalty * max((max_power - instance.maxCurtailment), 0)

    model = Model(Gurobi.Optimizer)

    # Add x_vs variables
    nbSubLocations = length(instance.substationLocations)
    nbSubTypes = length(instance.substationTypes)
    @variable(model, x[1:nbSubLocations, 1:nbSubTypes], Bin)

    # Add the constraints on substation locations. (1)
    for i in 1:nbSubLocations
        @constraint(model, sum(x[i, :]) <= 1)
    end

    # Add y_eq variables for land-substation cables
    nbLandCableTypes = length(instance.landSubstationCables)
    @variable(model, yland[1:nbSubLocations, 1:nbLandCableTypes], Bin)

    # Add the constraints on the land-substation cables. (2)
    for v in 1:nbSubLocations
        @constraint(model, sum(yland[v, :]) == sum(x[v, :]))
    end

    # Add z_vt variables
    nbTurbines = length(instance.windTurbine)
    @variable(model, z[1:nbSubLocations, 1:nbTurbines], Bin)

    # Add the constraints on the wind turbines. (3)
    for t in 1:nbTurbines
        @constraint(model, sum(z[:, t]) == 1)
    end

    # Ensure that each turbine is linked to a substation that is built

    for v in 1:nbSubLocations
        for t in 1:nbTurbines
            @constraint(model, sum(x[v, :]) >= z[v, t] )
        end 
    end

    # Add y_eq between substations variables
    nbSubCableTypes = length(instance.substationSubstationCables)
    @variable(model, ysub[1:nbSubLocations, 1:nbSubLocations, 1:nbSubCableTypes], Bin)

    # Add the constraints on the substation-substation cables. (4)
    # THIS IS NOT ENOUGH
    for v in 1:nbSubLocations
        @constraint(model, sum(ysub[v, :, :]) <= sum(x[v, :]))
    end
    # We need this for undirected cables
    for v1 in 1:nbSubLocations
        for v2 in 1:nbSubLocations
            @constraint(model, sum(ysub[v1, v1, :]) == 0)
                for i in 1:nbSubCableTypes
                    @constraint(model, ysub[v1, v2, i] == ysub[v2, v1, i])
            end
        end
    end

    # We will add a variable for the number of turbines linked to each substation
    # Because we will need use it multiple times in the constraints

    nbTurbinesLinked = @variable(model, [1:nbSubLocations])
    for v in 1:nbSubLocations
        @constraint(model, nbTurbinesLinked[v] == sum(z[v, :]))
    end
    ######################################

    # Variables for power sent from v1 to v2 under failure of v1
    # This is a min term, so we will need to linearize it

    @variable(model, powerSentUnderV1Failure[1:nbSubLocations, 1:nbSubLocations])
    @variable(model, minIsPowerSent[1:nbSubLocations, 1:nbSubLocations], Bin)
    @variable(model, minIsCableCapa[1:nbSubLocations, 1:nbSubLocations], Bin)

    for v1 in 1:nbSubLocations
        for v2 in 1:nbSubLocations
            # Only one is the actual min
            @constraint(model, minIsPowerSent[v1, v2] + minIsCableCapa[v1, v2] == 1)
            power_sent = max_power * nbTurbinesLinked[v1]
            cable_capa = sum(instance.substationSubstationCables[i].rating * ysub[v1, v2, i] for i in 1:nbSubCableTypes)
            @constraint(model, powerSentUnderV1Failure[v1, v2] >= power_sent - minIsCableCapa[v1, v2] * max_power)
            @constraint(model, powerSentUnderV1Failure[v1, v2] >= cable_capa - minIsPowerSent[v1, v2] * max_power)
        end
    end
    
        

    # We add constraints to ensure each substation v1 can handle its linked turbines and itself under no failure
    # And the power sent from another substation under failure of this substation
    # And that the capacity of the cable to the main land is enough
    for v1 in 1:nbSubLocations
        capacitySub = sum(instance.substationTypes[i].rating * x[v1, i] for i in 1:nbSubTypes)
        capacityCable = sum(instance.landSubstationCables[i].rating * yland[v1, i] for i in 1:nbLandCableTypes)
        powerFromTurbines = nbTurbinesLinked[v1] * max_power
        for v2 in 1:nbSubLocations
            for c in 1:nbSubCableTypes
                powerFromOtherSubstations = powerSentUnderV1Failure[v2, v1]
                @constraint(model, ysub[v1, v2, c] --> {powerFromTurbines + powerFromOtherSubstations <= instance.maxCurtailment})
                @constraint(model, ysub[v1, v2, c] --> {capacitySub >= powerFromTurbines + powerFromOtherSubstations})
                @constraint(model, ysub[v1, v2, c] --> {capacityCable >= powerFromTurbines + powerFromOtherSubstations})
            end
        end
        @constraint(model, powerFromTurbines <= instance.maxCurtailment)
        @constraint(model, powerFromTurbines <= capacityCable)
        @constraint(model, powerFromTurbines <= capacitySub)
    end

    powerDelta = @variable(model, powerDelta[1:nbSubLocations])
    #Ensure that no power is lost in case of failure of a substation
    for v in 1:nbSubLocations
        powerHandled = nbTurbinesLinked[v] * max_power
        @constraint(model, powerDelta[v] == powerHandled 
            - sum(ysub[v, v2 , i] * instance.substationSubstationCables[i].rating for v2 in 1:nbSubLocations for i in 1:nbSubCableTypes))
        @constraint(model, powerDelta[v] <= instance.maxCurtailment)
    end

    # Operating cost

    probFailure = maximum([instance.substationTypes[i].probability_failure for i in 1:nbSubTypes])
    probFailure += maximum([instance.landSubstationCables[i].probability_failure for i in 1:nbLandCableTypes])

    opeCostSub = @variable(model, opeCostSub[1:nbSubLocations])
    for v in 1:nbSubLocations
        @constraint(model, opeCostSub[v] == instance.curtailingCost * probFailure * powerDelta[v])
    end

    operatingCost = @variable(model, operatingCost)
    @constraint(model, operatingCost == sum(opeCostSub))

    ######################################
    # Construction cost of the substations

    @variable(model, substationCost[1:nbSubLocations])

    for v in 1:nbSubLocations
        substation_cost = sum(instance.substationTypes[i].cost * x[v, i] for i in 1:nbSubTypes)
        @constraint(model, substationCost[v] == substation_cost)
    end

    # Construction cost of the land-substation cables

    @variable(model, landCableCost[1:nbSubLocations])

    for v in 1:nbSubLocations
        land_cable_cost = sum(instance.landSubstationCables[i].fixed_cost * yland[v, i] for i in 1:nbLandCableTypes)
        lengthCable = distance(instance.mainLandSubstation, instance.substationLocations[v])
        land_cable_cost += sum(instance.landSubstationCables[i].variable_cost * lengthCable * yland[v, i] for i in 1:nbLandCableTypes)
        @constraint(model, landCableCost[v] == land_cable_cost)
    end

    # Construction cost of the substation-substation cables

    @variable(model, subCableCost[1:nbSubLocations, 1:nbSubLocations])

    for v1 in 1:nbSubLocations
        for v2 in 1:nbSubLocations
            sub_cable_cost = sum(instance.substationSubstationCables[i].fixed_cost * ysub[v1, v2, i] for i in 1:nbSubCableTypes)
            lengthCable = distance(instance.substationLocations[v1], instance.substationLocations[v2])
            sub_cable_cost += sum(instance.substationSubstationCables[i].variable_cost * lengthCable * ysub[v1, v2, i] for i in 1:nbSubCableTypes)
            @constraint(model, subCableCost[v1, v2] == sub_cable_cost)
        end
    end

    #Construction cost for the turbine - substation links

    turbineCableCost = @variable(model, [1:nbSubLocations, 1:nbTurbines])

    for v in 1:nbSubLocations
        for t in 1:nbTurbines
            cable_cost = instance.fixedCostCable * z[v, t]
            lengthCable = distance(instance.substationLocations[v], instance.windTurbine[t])
            cable_cost += instance.variableCostCable * lengthCable * z[v, t]
            @constraint(model, turbineCableCost[v, t] == cable_cost)
        end
    end 


    # Total construction cost

    constructionCost = @variable(model)

    @constraint(model, constructionCost == sum(substationCost) + sum(landCableCost) + sum(subCableCost) + sum(turbineCableCost))

    # objective function

    @objective(model, Min, constructionCost + operatingCost)

    optimize!(model)

    time = solve_time(model)

    solution = toSolution(value.(x), value.(yland), value.(ysub), value.(z), instance)

    if filename != ""
        rawData = Dict(
            "x" => value.(x),
            "yland" => value.(yland),
            "ysub" => value.(ysub),
            "z" => value.(z), 
        )
        open(filename, "w") do f
            JSON.print(f, rawData)
        end
    end
    return solution, time
end