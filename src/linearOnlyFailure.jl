include("instance.jl")
include("solution.jl")

using JuMP, Gurobi, JSON

function linearOnlyFailure(instance :: Instance,  filename :: String = "")
    # We need to compute an upper bound for the curtailing cost under failure (At first we can compute one for every scenario)
    nbScenarios = length(instance.windScenarios)
    max_power = maximum([instance.windScenarios[i].power for i in 1:nbScenarios]) * length(instance.windTurbine)
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
        for v in 1:nbSubLocations
            @constraint(model, z[v, t] <= sum(x[v, :]))
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

    # We will add some parts of the objective function as variables to make it easier to read

    # Using what we proved in question 5 of the report
    # We can write the no-curtailing cost as follows, by adding two variables per substation
    # So as to linearize the [power_received - min(capa_sub, capa_cable)]⁺ terms

    #This corresponds to the -min(capa_sub, capa_cable) part
    minusCapa = @variable(model, [1:nbSubLocations])

    substation_ratings = [instance.substationTypes[i].rating for i in 1:nbSubTypes]
    landCable_ratings = [instance.landSubstationCables[i].rating for i in 1:nbLandCableTypes]
    for v in 1:nbSubLocations
        @constraint(model, minusCapa[v] >= - sum(substation_ratings[i] * x[v, i] for i in 1:nbSubTypes))
        @constraint(model,minusCapa[v] >= - sum(landCable_ratings[i] * yland[v, i] for i in 1:nbLandCableTypes))
    end

    # We then add variables for the curtailing of each substation under each scenario

    # Then variables for the power sent from substation v1 to v2 under scenario ω
    # Here we will need to truly linearize the min(power_received by v1, capa_cable(v1, v2)) term 
    # For this we can use the method described in the report, question 3

    # Curtailing of the substation v under scenario ω and failure of v 
    # (power that can't be transfered by the SubSubCables)
    # This is the positive part of [power_received - capa_cable(v1, v2)]⁺
    @variable(model, curtailingUnderOwnFailure[1:nbSubLocations, 1:nbScenarios])

    for ω in 1:nbScenarios
        for v in 1:nbSubLocations
            @constraint(model, curtailingUnderOwnFailure[v, ω] >= 0)
            power_received = instance.windScenarios[ω].power * nbTurbinesLinked[v]
            capa_cable = sum(instance.substationSubstationCables[j].rating * ysub[v, i, j] for i in 1:nbSubLocations for j in 1:nbSubCableTypes)
            @constraint(model, curtailingUnderOwnFailure[v, ω] >= power_received - capa_cable)
        end
    end

    # Variables for power sent from v1 to v2 under scenario ω and failure of v1
    # This is a min term, so we will need to linearize it

    @variable(model, powerSentUnderOtherFailure[1:nbSubLocations, 1:nbSubLocations, 1:nbScenarios])
    @variable(model, minIsPowerSent[1:nbSubLocations, 1:nbSubLocations, 1:nbScenarios], Bin)
    @variable(model, minIsCableCapa[1:nbSubLocations, 1:nbSubLocations, 1:nbScenarios], Bin)

    for ω in 1:nbScenarios
        for v1 in 1:nbSubLocations
            for v2 in 1:nbSubLocations
                # Only one is the actual min
                @constraint(model, minIsPowerSent[v1, v2, ω] + minIsCableCapa[v1, v2, ω] == 1)
                power_sent = instance.windScenarios[ω].power * nbTurbinesLinked[v1]
                cable_capa = sum(instance.substationSubstationCables[i].rating * ysub[v1, v2, i] for i in 1:nbSubCableTypes)
                @constraint(model, powerSentUnderOtherFailure[v1, v2, ω] >= power_sent - minIsCableCapa[v1, v2, ω] * max_power)
                @constraint(model, powerSentUnderOtherFailure[v1, v2, ω] >= cable_capa - minIsPowerSent[v1, v2, ω] * max_power)
            end
        end
    end

    # Curtailing of the substation v2 under scenario ω and failure of v1

    @variable(model, curtailingUnderOtherFailure[1:nbSubLocations, 1:nbSubLocations, 1:nbScenarios])

    for ω in 1:nbScenarios
        for v1 in 1:nbSubLocations
            for v2 in 1:nbSubLocations
                if v2 != v1
                    @constraint(model, curtailingUnderOtherFailure[v1, v2, ω] >= 0)
                    power_received_from_turbines = instance.windScenarios[ω].power * nbTurbinesLinked[v2]
                    power_received_from_other = powerSentUnderOtherFailure[v1, v2, ω]
                    @constraint(model, curtailingUnderOtherFailure[v1, v2, ω] >= power_received_from_turbines + power_received_from_other + minusCapa[v2])
                else 
                    @constraint(model, curtailingUnderOtherFailure[v1, v1, ω] == 0)
                end
            end
        end
    end

    # Total curtailing under failure of v1 and scenario ω

    @variable(model, curtailingUnderFailure[1:nbSubLocations, 1:nbScenarios])

    for ω in 1:nbScenarios
        for v in 1:nbSubLocations
            @constraint(model, curtailingUnderFailure[v, ω] == curtailingUnderOwnFailure[v, ω] + sum(curtailingUnderOtherFailure[v, :, ω]))
        end
    end

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

    @constraint(model, constructionCost == sum(substationCost) + sum(landCableCost) + sum(subCableCost) / 2 + sum(turbineCableCost))

    # Cost of the curtailment per substation, per scenario (This is c^c(C^f(v, ω)))

    curtailmentCostFailure = @variable(model, [1:nbSubLocations, 1:nbScenarios])

    for ω in 1:nbScenarios
        for v in 1:nbSubLocations
            linear_part = instance.curtailingCost * curtailingUnderFailure[v, ω]
            penalty_part = instance.curtailingPenalty * (curtailingUnderFailure[v, ω] - instance.maxCurtailment)
            @constraint(model, curtailmentCostFailure[v, ω] >= linear_part)
            @constraint(model, curtailmentCostFailure[v, ω] >= penalty_part + linear_part)
        end
    end

    # Cost of the curtailment, under no failure (This is c^c(C^n(ω)))

    curtailmentCostNoFailure = @variable(model, [1:nbScenarios])

    for ω in 1:nbScenarios
        linear_part = instance.curtailingCost * curtailingNoFailure[ω]
        penalty_part = instance.curtailingPenalty * (curtailingNoFailure[ω] - instance.maxCurtailment)
        @constraint(model, curtailmentCostNoFailure[ω] >= linear_part)
        @constraint(model, curtailmentCostNoFailure[ω] >= penalty_part + linear_part)
    end

    # Weighted costs, this is the terms p^f(v) * c^c(C^f(v, ω))


    @variable(model, weightedCurtailingCostFailure[1:nbSubLocations, 1:nbScenarios])
    @variable(model, xvsTimesCurtailingCostFailure[1:nbSubLocations, 1:nbSubTypes, 1:nbScenarios])
    @variable(model, yeqTimesCurtailingCostFailure[1:nbSubLocations, 1:nbLandCableTypes, 1:nbScenarios])


    for ω in 1:nbScenarios
        for v in 1:nbSubLocations
            for s in 1:nbSubTypes
                @constraint(model, xvsTimesCurtailingCostFailure[v, s, ω] <= x[v, s] * max_cost)
                @constraint(model, xvsTimesCurtailingCostFailure[v, s, ω] <= curtailmentCostFailure[v, ω])
                @constraint(model, xvsTimesCurtailingCostFailure[v, s, ω] >= curtailmentCostFailure[v, ω] - (1 - x[v, s]) * max_cost)
                @constraint(model, xvsTimesCurtailingCostFailure[v, s, ω] >= 0)
            end
            for q in 1:nbLandCableTypes
                @constraint(model, yeqTimesCurtailingCostFailure[v, q, ω] <= yland[v, q] * max_cost)
                @constraint(model, yeqTimesCurtailingCostFailure[v, q, ω] <= curtailmentCostFailure[v, ω])
                @constraint(model, yeqTimesCurtailingCostFailure[v, q, ω] >= curtailmentCostFailure[v, ω] - (1 - yland[v, q]) * max_cost)
                @constraint(model, yeqTimesCurtailingCostFailure[v, q, ω] >= 0)
            end
            @constraint(model, weightedCurtailingCostFailure[v, ω] == sum(
                [xvsTimesCurtailingCostFailure[v, s, ω] * instance.substationTypes[s].probability_failure for s in 1:nbSubTypes])
                + sum([yeqTimesCurtailingCostFailure[v, q, ω] * instance.landSubstationCables[q].probability_failure for q in 1:nbLandCableTypes])
            ) 
        end
    end

    # Failure cost, sum of the weighted costs over the substations
    failureCostUnderOmega = @variable(model, [1:nbScenarios])

    for ω in 1:nbScenarios
        @constraint(model, failureCostUnderOmega[ω] == sum(weightedCurtailingCostFailure[:, ω]))
    end

   

    operationalCost = @variable(model)

    @constraint(model, operationalCost == sum([instance.windScenarios[ω].probability * (failureCostUnderOmega[ω]) for ω in 1:nbScenarios]))

    # objective function

    @objective(model, Min, constructionCost + operationalCost)

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