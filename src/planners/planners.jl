## Abstract interface for planners and solutions ##
export Planner, Solution, OrderedSolution

"Abstract planner type, which defines the interface for planners."
abstract type Planner end

(planner::Planner)(domain::Domain, state::State, goal_spec) =
    solve(planner, domain, state, goal_spec)

solve(planner::Planner, domain::Domain, state::State, goal::GoalSpec) =
    error("Not implemented.")
solve(planner::Planner, domain::Domain, state::State, goals::Vector{<:Term}) =
    solve(planner, domain, state, GoalSpec(goals))
solve(planner::Planner, domain::Domain, state::State, goal::Term) =
    solve(planner, domain, state, GoalSpec(goal))

"Abstract solution type, which defines the interface for planner solutions."
abstract type Solution end

"Abstract type for ordered planner solutions."
abstract type OrderedSolution <: Solution end

# Ordered solutions should support indexing and iteration over action terms
Base.iterate(::OrderedSolution) = error("Not implemented.")
Base.iterate(::OrderedSolution, state) = error("Not implemented.")
Base.getindex(::OrderedSolution, ::Int) = error("Not implemented.")
Base.eltype(::Type{OrderedSolution}) = Term

"Null solution that indicates no plan was found."
struct NullSolution <: Solution end

include("common.jl")
include("bfs.jl")
include("forward.jl")
include("backward.jl")
include("external.jl")
