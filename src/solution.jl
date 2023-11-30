
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