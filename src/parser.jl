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
        JSON.print(f, data)
    end
end

