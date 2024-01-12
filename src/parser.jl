import JSON
include("constants.jl")
include("instance.jl")
include("solution.jl")

function read_instance(filename :: String) :: Instance
    data = JSON.parsefile(filename)
    general_parameters = data[GEN_PARAMETERS]
    landSubstationCable_data = data[LAND_SUB_CABLE_TYPES]
    substationSubstationCable_data = data[SUB_SUB_CABLE_TYPES]
    substationLocation_data = data[SUBSTATION_LOCATION]
    windTurbines_data = data[WIND_TURBINES]
    windScenarios_data = data[WIND_SCENARIOS]
    substationTypes_data = data[SUBSTATION_TYPES]
    # Substation types
    substationTypes = [
        SubstationType(
            type[ID],
            type[COST],
            type[RATING],
            type[PROB_FAIL]
        ) for type in substationTypes_data
    ]
    # Land-Substation cables
    landSubstationCables = [
        CableType(
            cable[ID],
            cable[FIX_COST],
            cable[VAR_COST],
            cable[RATING],
            cable[PROB_FAIL]
        ) for cable in landSubstationCable_data
    ]
    # Substation-Substation cables
    substationSubstationCables = [
        CableType(
            cable[ID],
            cable[FIX_COST],
            cable[VAR_COST],
            cable[RATING],
            0.0
        ) for cable in substationSubstationCable_data
    ]
    # Substation Location
    subsationLocations = [
        Location(
            loc[ID],
            loc[X],
            loc[Y]
        ) for loc in substationLocation_data
    ]
    # Wind Turbines
    windTurbines = [
        Location(
            turbine[ID],
            turbine[X],
            turbine[Y]
        ) for turbine in windTurbines_data
    ]
    # Wind Scenarios
    windScenarios = [
        WindScenario(
            scenario[ID],
            scenario[POWER_GENERATION],
            scenario[PROBABILITY]
        ) for scenario in windScenarios_data
    ]
    # Main land station 
    mainLandStation = Location(
        0,
        general_parameters[MAIN_LAND_STATION][X],
        general_parameters[MAIN_LAND_STATION][Y]
    )
    instance = Instance(
        general_parameters[CURTAILING_COST],
        general_parameters[CURTAILING_PENA],
        general_parameters[MAX_CURTAILING],
        general_parameters[FIX_COST_CABLE],
        general_parameters[VAR_COST_CABLE],
        mainLandStation,
        general_parameters[MAX_POWER],
        landSubstationCables,
        substationSubstationCables,
        subsationLocations,
        substationTypes,
        windScenarios,
        windTurbines
    )
    return instance
end

function write_instance(instance :: Instance, filename :: String)
    data = Dict()
    data[GEN_PARAMETERS] = Dict(
        CURTAILING_COST => instance.curtailingCost,
        CURTAILING_PENA => instance.curtailingPenalty,
        MAX_CURTAILING => instance.maxCurtailment,
        FIX_COST_CABLE => instance.fixedCostCable,
        VAR_COST_CABLE => instance.variableCostCable,
        MAX_POWER => instance.maximumPower,
        MAIN_LAND_STATION => Dict(
            X => instance.mainLandSubstation.x,
            Y => instance.mainLandSubstation.y
        )
    )

    data[SUBSTATION_LOCATION] = [
        Dict(
            ID => substation.id,
            X => substation.x,
            Y => substation.y
        ) for substation in instance.substationLocations
    ]

    data[LAND_SUB_CABLE_TYPES] = [
        Dict(
            ID => cable.id,
            FIX_COST => cable.fixed_cost,
            VAR_COST => cable.variable_cost,
            RATING => cable.rating,
            PROB_FAIL => cable.probability_failure
        ) for cable in instance.landSubstationCables
    ]

    data[SUB_SUB_CABLE_TYPES] = [
        Dict(
            ID => cable.id,
            FIX_COST => cable.fixed_cost,
            VAR_COST => cable.variable_cost,
            RATING => cable.rating
        ) for cable in instance.substationSubstationCables
    ]

    data[SUBSTATION_TYPES] = [
        Dict(
            ID => type.id,
            COST => type.cost,
            RATING => type.rating,
            PROB_FAIL => type.probability_failure
        ) for type in instance.substationTypes
    ]

    data[WIND_SCENARIOS] = [
        Dict(
            ID => scenario.id,
            POWER_GENERATION => scenario.power,
            PROBABILITY => scenario.probability
        ) for scenario in instance.windScenarios
    ]

    data[WIND_TURBINES] = [
        Dict(
            ID => turbine.id,
            X => turbine.x,
            Y => turbine.y
        ) for turbine in instance.windTurbine
    ]

    open(filename, "w") do f
        JSON.print(f, data, 4)
    end
end

function read_solution(filename :: String)
    data = JSON.parsefile(filename)
    raw_substations = data[SUBSTATIONS]
    raw_turbines = data[TURBINES]
    raw_cables = data[SUBSTATION_SUBSTATION_CABLES]

    substations = [ Substation(sub[ID] , sub[LAND_CABLE_TYPE], sub[SUB_TYPE])
        for sub in raw_substations]

    wind_turbines = [ WindTurbine(turbine[ID], turbine[SUBSTATION_ID])
        for turbine in raw_turbines]

    cables = [ Cable(cable[CABLE_TYPE_SUBSUB], cable[SUBSTATION_ID], cable[OTHER_SUB_ID])
        for cable in raw_cables]

    return Solution(substations, cables, wind_turbines)

end 

function writeSolution(solution :: Solution, path :: String)
    data = Dict()
    #Substations
    data[SUBSTATIONS] = []
    for substation in solution.substations
        push!(
            data[SUBSTATIONS],
            Dict(
                ID => substation.id_loc,
                SUB_TYPE => substation.id_type,
                LAND_CABLE_TYPE => substation.id_cable
            )
        )
    end
    #Substation-Substation cables
    data[SUBSTATION_SUBSTATION_CABLES] = []
    for cable in solution.cables
        push!(
            data[SUBSTATION_SUBSTATION_CABLES],
            Dict(
                SUBSTATION_ID => cable.id_sub1,
                OTHER_SUB_ID => cable.id_sub2,
                CABLE_TYPE_SUBSUB => cable.id_type
            )
        )
    end
    #Turbines
    data[TURBINES] = []
    for turbine in solution.windTurbines
        push!(
            data[TURBINES],
            Dict(
                ID => turbine.id_loc,
                SUBSTATION_ID => turbine.id_sub
            )
        )
    end
    open(path, "w") do f
        JSON.print(f, data, 4)
    end
end

function appendCostToFile(path :: String, cost :: Tuple{Float64, Float64, Float64}, aggregationType :: String, size :: String)
    data = JSON.parsefile(path)
    cons, ope, total = cost
    data[aggregationType * "-" * size] = Dict(
        "construction"=> cons,
        "operationnal" => ope,
        "total" => total
    )
    open(path, "w") do f
        JSON.print(f, data, 4)
    end
end