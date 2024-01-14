include("instance.jl")
include("solution.jl")
include("parser.jl")

using GLMakie

function plotInstance(instance::Instance; legendpos=:lt)
    X_stations = [l.x for l in instance.substationLocations]
    Y_stations = [l.y for l in instance.substationLocations]

    X_turbines = [l.x for l in instance.windTurbine]
    Y_turbines = [l.y for l in instance.windTurbine]

    X_land = instance.mainLandSubstation.x
    Y_land = instance.mainLandSubstation.y

    f = Figure()
    ax = Axis(f[1, 1]; title="Instance", xlabel="x", ylabel="y")#, aspect=DataAspect())
    scatter!(ax, X_land, Y_land; label="Land", color=:green, markersize=20)
    scatter!(
        ax,
        X_stations,
        Y_stations;
        label="Substations",
        color=:orange,
        markersize=20,
        marker=:utriangle,
    )
    scatter!(
        ax,
        X_turbines,
        Y_turbines;
        label="Turbines",
        color=:purple,
        markersize=10,
        marker=:star4,
    )
    axislegend(ax; position=legendpos)
    return f
end

function plotSolution(solution::Solution, instance::Instance)
    f = plotInstance(instance)
    # Turbine links
    for turbine in solution.windTurbines
        lines!(
            f[1, 1],
            [instance.windTurbine[turbine.id_loc].x, instance.substationLocations[turbine.id_sub].x],
            [instance.windTurbine[turbine.id_loc].y, instance.substationLocations[turbine.id_sub].y];
            color=:black,
        )
    end
    # Substations links
    for substation in solution.substations
        lines!(
            f[1, 1],
            [instance.substationLocations[substation.id_loc].x, instance.mainLandSubstation.x],
            [instance.substationLocations[substation.id_loc].y, instance.mainLandSubstation.y];
            color=:black,
        )
    end
    # Inter station cables
    for cable in solution.cables
        lines!(
            f[1, 1],
            [instance.substationLocations[cable.id_sub1].x, instance.substationLocations[cable.id_sub2].x],
            [instance.substationLocations[cable.id_sub1].y, instance.substationLocations[cable.id_sub2].y];
            color=:black,
        )
    end
    return f
end

function plotAllInstances(namingFormat :: String = "KIRO")
    sizes = ["small", "medium", "large", "huge"]
    for size ∈ sizes
        instance = read_instance("instances/aggregated/$namingFormat-$size.json")
        f = plotInstance(instance)
        save("plots/$namingFormat-$size.png", f)
    end
end

function plotPowerProba(instance::Instance)
    Y_power = [l.power for l in instance.windScenarios]
    X_proba = [l.probability for l in instance.windScenarios]    
    f = Figure()
    ax = Axis(f[1, 1]; title="scenarios", xlabel="proba", ylabel="power")#, aspect=DataAspect())
    scatter!(ax, X_proba, Y_power; label = "Scenarios", color=:green, markersize=20)
    return f
end

function plotLandCable(instance::Instance)
    fixedCosts = [c.fixed_cost for c in instance.landSubstationCables]
    variableCosts = [c.variable_cost for c in instance.landSubstationCables]
    failureProbas = [c.probability_failure for c in instance.landSubstationCables]
    ratings = [c.rating for c in instance.landSubstationCables]
    f = Figure()
    ax2 = Axis(f[1, 1]; title="Land cables", xlabel="Probability of failure", ylabel="Rating")
    scatter!(ax2, failureProbas, ratings, color=variableCosts, markersize=20)
    Colorbar(f[1, 2], limits = (minimum(variableCosts), maximum(variableCosts)), label = "variable cost")
    return f
end

function plotUsedLandCable(instance :: Instance, solution :: Solution)
    usedCables = [instance.landSubstationCables[sub.id_cable] for sub in solution.substations]
    probas = [c.probability_failure for c in usedCables]
    ratings = [c.rating for c in usedCables]
    f = plotLandCable(instance)
    ax = f[1, 1]
    scatter!(ax, probas, ratings; color=:red, markersize=15, marker = :cross)
    return f
end


function plotSubstationTypes(instance :: Instance)
    costs = [s.cost for s in instance.substationTypes]
    ratings = [s.rating for s in instance.substationTypes]
    failureProbas = [s.probability_failure for s in instance.substationTypes]
    f = Figure()
    ax2 = Axis(f[1, 1]; title="Substation types", xlabel="Probability of failure", ylabel="Rating")
    scatter!(ax2, failureProbas, ratings, color=costs, markersize=20)
    Colorbar(f[1, 2], limits = (minimum(costs), maximum(costs)), label = "cost")
    return f
end

function plotUsedSubstationTypes(instance :: Instance, solution :: Solution)
    usedSubstations = [instance.substationTypes[sub.id_type] for sub in solution.substations]
    probas = [s.probability_failure for s in usedSubstations]
    ratings = [s.rating for s in usedSubstations]
    f = plotSubstationTypes(instance)
    ax = f[1, 1]
    scatter!(ax, probas, ratings; color=:red, markersize=15, marker = :cross)
    return f
end

function plotUsedTypes(instance :: Instance, reducedInstance :: Instance, solution :: Solution)
    f = Figure()
    varCostCable = [c.variable_cost for c in instance.landSubstationCables]
    probCable = [c.probability_failure for c in instance.landSubstationCables]
    ratingCable = [c.rating for c in instance.landSubstationCables]
    CostSub = [s.cost for s in instance.substationTypes]
    probSub = [s.probability_failure for s in instance.substationTypes]
    ratingSub = [s.rating for s in instance.substationTypes]

    ax1 = Axis(f[1, 1]; title="Land cables", xlabel="Probability of failure", ylabel="Rating")
    scatter!(ax1, probCable, ratingCable; color=varCostCable, markersize=20)
    Colorbar(f[1, 2], limits = (minimum(varCostCable), maximum(varCostCable)), label = "Variable cost")

    ax2 = Axis(f[1, 3]; title="Substation types", xlabel="Probability of failure", ylabel="Rating")
    scatter!(ax2, probSub, ratingSub; color=CostSub, markersize=20)
    Colorbar(f[1, 4], limits = (minimum(CostSub), maximum(CostSub)), label = "Cost")

    usedCables = [instance.landSubstationCables[sub.id_cable].id for sub in solution.substations]
    scatter!(ax1, probCable[usedCables], ratingCable[usedCables]; color=:red, markersize=15, marker = :cross)

    usedSubstations = [instance.substationTypes[sub.id_type].id for sub in solution.substations]
    scatter!(ax2, probSub[usedSubstations], ratingSub[usedSubstations]; color=:red, markersize=15, marker = :cross)

    redProbCable = [c.probability_failure for c in reducedInstance.landSubstationCables]
    redRatingCable = [c.rating for c in reducedInstance.landSubstationCables]
    redProbSub = [s.probability_failure for s in reducedInstance.substationTypes]
    redRatingSub = [s.rating for s in reducedInstance.substationTypes]

    scatter!(ax1, redProbCable, redRatingCable; color=:blue, markersize=15, marker = :xcross)
    scatter!(ax2, redProbSub, redRatingSub; color=:blue, markersize=15, marker = :xcross)

    return f
end

