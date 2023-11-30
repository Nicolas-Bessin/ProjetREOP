
struct CableType
    id :: Int64
    fixed_cost :: Float64
    variable_cost :: Float64
    rating :: Float64
    probability_failure :: Float64
end 

struct SubstationType
    id :: Int64
    cost :: Float64
    rating :: Float64
    probability_failure :: Float64
end

struct Location
    id :: Int64
    x :: Float64
    y :: Float64
end

function distance(a::Location, b::Location)
    return sqrt((a.x - b.x)^2 + (a.y - b.y)^2)
end

struct WindScenario
    id :: Int64
    power :: Float64
    probability :: Float64
end

struct Instance
    curtailingCost :: Float64
    curtailingPenalty :: Float64
    maxCurtailment :: Float64
    fixedCostCable :: Float64
    variableCostCable :: Float64
    mainLandSubstation :: Location
    maximumPower :: Float64
    landSubstationCables :: Vector{CableType}
    substationSubstationCables :: Vector{CableType}
    substationLocations :: Vector{Location}
    substationTypes :: Vector{SubstationType}
    windScenarios :: Vector{WindScenario}
    windTurbine :: Vector{Location}
end
