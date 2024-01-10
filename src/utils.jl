include("instance.jl")
include("solution.jl")
include("parser.jl")

using GLMakie

sizes = ["tiny", "small", "medium", "large", "huge"]

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

# for size ∈ sizes
#     instance = read_instance("instances/KIRO-$size.json")
#     f = plotInstance(instance)
#     save("plots/instance-$size.png", f)
# end

size = "tiny"

instance = read_instance("instances/KIRO-$size.json")
solution = read_solution("solutions/KIRO-$size-sol-linear.json")
f = plotSolution(solution, instance)
save("plots/instance-$size-linearized.png", f)