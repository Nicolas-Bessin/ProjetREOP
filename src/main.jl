include("parser.jl")
include("linearSolverCode.jl")
include("utils.jl")

# Optimal value for linear : 3.181693050869e+04
# Optimal value for mean scenario : 3.111073854492e+04

size = "small"
inputFile = "instances/aggregated/KIRO-$size-mean.json"
outputFile = "solutions/aggregated/KIRO-$size-mean.json"
instance = read_instance(inputFile)

solution = linearSolver(instance)
writeSolution(solution, outputFile)
figure = plotSolution(solution, instance)
save("plots/instance-$size-linear-mean.png", f)