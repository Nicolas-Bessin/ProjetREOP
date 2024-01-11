# tri des scenarios par puissance
include("instance.jl")
include("solution.jl")
include("parser.jl")

using GLMakie
size = "small"
sizes = ["tiny", "small", "medium", "large", "huge"]
input = "instances/KIRO-$size.json"

instance = read_instance(input) :: Instance

nbScenarios = length(instance.windScenarios)

# Function to order wind scenarios by power generation
function order_scenarios_by_power(scenarios)
    return sort(scenarios, by = x -> x.power)
end

# plotting

function plotpowprob(instance::Instance; legendpos=:lt)
    ordered_scenarios = order_scenarios_by_power(instance.windScenarios)
    Y_power = [l.power for l in ordered_scenarios]
    X_proba = [l.probability for l in ordered_scenarios]    
    f = Figure()
    ax = Axis(f[1, 1]; title="scenarios", xlabel="proba", ylabel="power")#, aspect=DataAspect())
    scatter!(ax, X_proba, Y_power; label = "Scenarios", color=:green, markersize=20)
    return f
end

f = plotpowprob(instance)
save("plots/powprob-$size.png", f)

# The scenarios look uniformly spread by power, so we can group them by classes of power to reduce
# the number of scenarios

function classify_scenarios(instance::Instance,nb_agr_scen)
    # returns an instance with nb_agr_scen scenarios that represent the mean of scenarios on the classes 
    # with classes being quantiles on the power
    # ex : nb_agr_scen = 4 leads to 4 quantiles
    # the power of obtained scenarios is the mean power of all scenario in the corresponding class
    # the probability of obtained scenario is the sum of all probabilities of all scenario in the corresponding class

    ordered_scenarios = order_scenarios_by_power(instance.windScenarios)
    nb_Scenarios = length(instance.windScenarios)

    # initialization of the nb_agr_scen scenarios
    agregated_wind_scenarios = []

    # repartition of the scenarios on their power
    j = 1
    for i in 1:(nb_agr_scen)
        avg_pow = 0
        sum_proba = 0
        while j <= (i/nb_agr_scen) * nb_Scenarios && j <= nb_Scenarios
            avg_pow += ordered_scenarios[j].power * ordered_scenarios[j].probability
            sum_proba += ordered_scenarios[j].probability
            j += 1
        end
        push!(agregated_wind_scenarios, WindScenario(i,avg_pow/sum_proba,sum_proba))
    end
    meanTotalPower = sum([w.power * w.probability for w in instance.windScenarios])
    meanClassesPower = sum([w.power * w.probability for w in agregated_wind_scenarios])
    return Instance(
        instance.curtailingCost,
        instance.curtailingPenalty,
        instance.maxCurtailment,
        instance.fixedCostCable,
        instance.variableCostCable,
        instance.mainLandSubstation,
        ordered_scenarios[nb_Scenarios].power,
        instance.landSubstationCables,
        instance.substationSubstationCables,
        instance.substationLocations,
        instance.substationTypes,
        agregated_wind_scenarios,
        instance.windTurbine,
    )
end

function aggregateMeanInstance(nb_agr_scen)
    for size in sizes
        inputFile = "instances/KIRO-$size.json"
        outputFile = "instances/aggregated/KIRO-$size-$nb_agr_scen-scen.json"
        originalInstance = read_instance(inputFile)
        meanInstance = classify_scenarios(originalInstance,nb_agr_scen)
        write_instance(meanInstance, outputFile)
    end
end

aggregateMeanInstance(4)


