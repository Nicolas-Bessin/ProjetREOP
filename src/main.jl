include("parser.jl")
include("linearSolverCode.jl")
include("utils.jl")
include("costCompute.jl")
include("agregator.jl")

# Optimal value for linear : 3.181693050869e+04
# Optimal value for mean scenario : 3.111073854492e+04

size = "small"
aggregationMethod = ""
aggrFunction = idem

trueInstanceFile = "instances/KIRO-$size.json"
outputFile = "solutions/aggregated/KIRO$aggregationMethod-$size.json"

trueInstance = read_instance(trueInstanceFile)
instance = aggrFunction(trueInstance)

solution = linearSolver(instance)
writeSolution(solution, outputFile)
figure = plotSolution(solution, trueInstance)
save("plots/instance-$size$aggregationMethod.png", f)

falseCost = costOfSolution(instance, solution)
cost = costOfSolution(trueInstance, solution)