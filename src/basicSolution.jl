include("parser.jl")
size = "tiny"
input = "instances/KIRO-$size.json"
output = "solutions/KIRO-$(size)_sol1.json"

instance = read_instance(input)