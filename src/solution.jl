
struct Substation
    id_loc :: Int64
    id_type :: Int64
    id_cable :: Int64
end

struct Cable
    id_type :: Int64
    id_sub1 :: Int64
    id_sub2 :: Int64
end

struct WindTurbine
    id_loc :: Int64
    id_sub :: Int64
end

struct Solution
    substations :: Vector{Substation}
    cables :: Vector{Cable}
    windTurbines :: Vector{WindTurbine}
end

function toSolution(x, yland, ysub, z, instance)
    substations = []
    cables = []
    windTurbines = []
    #Add the substations
    for v in 1:length(instance.substationLocations)
        for s in 1:length(instance.substationTypes)
            if x[v, s] > 0.5
                #Find the associated cable
                for c in 1:length(instance.landSubstationCables)
                    if yland[v, c] > 0.5
                        push!(substations, Substation(v, s, c))
                    end
                end
            end
        end 
    end
    #Add the wind turbines
    for t in 1:length(instance.windTurbine)
        for v in 1:length(instance.substationLocations)
            if z[v, t] > 0.5
                push!(windTurbines, WindTurbine(t, v))
            end
        end
    end
    #Add the substation - substation cables
    for v1 in 1:length(instance.substationLocations)
        for v2 in 1:length(instance.substationLocations)
            for c in 1:length(instance.substationSubstationCables)
                if ysub[v1, v2, c] > 0.5
                    push!(cables, Cable(c, v1, v2))
                end
            end
        end
    end
    return Solution(substations, cables, windTurbines)

end