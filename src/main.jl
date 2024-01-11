include("parser.jl")
include("linearSolverCode.jl")
include("utils.jl")
include("costCompute.jl")

# Optimal value for linear : 3.181693050869e+04
# Optimal value for mean scenario : 3.111073854492e+04

size = "small"
inputFile = "instances/aggregated/KIRO-$size-mean.json"
trueInstanceFile = "instances/KIRO-$size.json"
outputFile = "solutions/aggregated/KIRO-$size-mean.json"
instance = read_instance(inputFile)
trueInstance = read_instance(trueInstanceFile)

solution = linearSolver(instance)
writeSolution(solution, outputFile)
figure = plotSolution(solution, trueInstance)
save("plots/instance-$size-linear-mean.png", f)

cost = costOfSolution(trueInstance, solution)