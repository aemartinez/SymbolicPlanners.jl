## Utilities and solutions for path search algorithms ##
export PathSearchSolution

mutable struct PathNode{S<:State}
    id::UInt
    state::S
    path_cost::Float32
    parent_id::Union{UInt,Nothing}
    parent_action::Union{Term,Nothing}
end

PathNode(id, state::S, path_cost, parent_id, parent_action) where {S} =
    PathNode{S}(id, state, Float32(path_cost), parent_id, parent_action)
PathNode(id, state::S, path_cost) where {S} =
    PathNode{S}(id, state, Float32(path_cost), nothing, nothing)

function reconstruct(node_id::UInt, search_tree::Dict{UInt,PathNode{S}}) where S
    plan, traj = Term[], S[]
    while node_id in keys(search_tree)
        node = search_tree[node_id]
        pushfirst!(traj, node.state)
        if node.parent_id === nothing break end
        pushfirst!(plan, node.parent_action)
        node_id = node.parent_id
    end
    return plan, traj
end

"Solution type for search-based planners that produce fully ordered plans."
@auto_hash_equals mutable struct PathSearchSolution{
    S <: State, T
} <: OrderedSolution
    status::Symbol
    plan::Vector{Term}
    trajectory::Union{Vector{S},Nothing}
    expanded::Int
    search_tree::Union{Dict{UInt,PathNode{S}},Nothing}
    search_frontier::T
    search_order::Vector{UInt}
end

PathSearchSolution(status::Symbol, plan) =
    PathSearchSolution(status, convert(Vector{Term}, plan), nothing,
                       -1, nothing, nothing, UInt[])
PathSearchSolution(status::Symbol, plan, trajectory) =
    PathSearchSolution(status, convert(Vector{Term}, plan), trajectory,
                       -1, nothing, nothing, UInt[])

function Base.copy(sol::PathSearchSolution)
    plan = copy(sol.plan)
    trajectory = isnothing(sol.trajectory) ? nothing : copy(sol.trajectory)
    search_tree = isnothing(sol.search_tree) ? nothing : copy(sol.search_tree)
    search_frontier = isnothing(sol.search_frontier) ? nothing : copy(sol.search_frontier)
    search_order = copy(sol.search_order)
    return PathSearchSolution(sol.status, plan, trajectory, sol.expanded,
                              search_tree, search_frontier, search_order)
end

"""
Solution type for search-based planners that produce fully ordered plans.
"""
mutable struct BiPathSearchSolution{S<:State,T} <: OrderedSolution
    status::Symbol
    plan::Vector{Term}
    trajectory::Union{Vector{S},Nothing}
    expanded::Int
    f_search_tree::Union{Dict{UInt,PathNode{S}},Nothing}
    f_frontier::T
    f_expanded::Int
    f_trajectory::Union{Vector{S},Nothing}
    b_search_tree::Union{Dict{UInt,PathNode{S}},Nothing}
    b_frontier::T
    b_expanded::Int
    b_trajectory::Union{Vector{S},Nothing}
end

BiPathSearchSolution(status::Symbol, plan) =
    BiPathSearchSolution(status, plan, nothing, -1, nothing, nothing, -1, nothing, nothing, nothing, -1, nothing)
BiPathSearchSolution(status::Symbol, plan, trajectory) =
    BiPathSearchSolution(status, plan, trajectory, -1, nothing, nothing, -1, nothing, nothing, nothing, -1, nothing)

function Base.copy(sol::BiPathSearchSolution)
    fields = map(fieldnames(BiPathSearchSolution)) do field 
        x = getfield(sol, field)
        (x isa Symbol || isnothing(x)) && return(x)
        copy(x)
    end
    return BiPathSearchSolution(fields...)
end

const SearchSolutions = Union{PathSearchSolution, BiPathSearchSolution}

function Base.show(io::IO, sol::SearchSolutions)
    pl = sol.status == :success ? length(sol.plan) : "-"
    println(io, "BiPathSearchSolution: (", sol.status, ", ", pl, ", ", sol.expanded, ")")
end

Base.iterate(sol::SearchSolutions) = iterate(sol.plan)
Base.iterate(sol::SearchSolutions, istate) = iterate(sol.plan, istate)
Base.getindex(sol::SearchSolutions, i::Int) = getindex(sol.plan, i)
Base.length(sol::SearchSolutions) = length(sol.plan)

get_action(sol::SearchSolutions, t::Int) = sol.plan[t]

function get_action(sol::SearchSolutions, state::State)
    idx = findfirst(==(state), sol.trajectory)
    if isnothing(idx) || idx == length(sol.trajectory)
        return missing
    else
        return sol.plan[idx]
    end
end

function get_action(sol::SearchSolutions, t::Int, state::State)
    return isnothing(sol.trajectory) ?
        get_action(sol, t) : get_action(sol, state)
end

best_action(sol::SearchSolutions, state::State) = get_action(sol, state)
rand_action(sol::SearchSolutions, state::State) = get_action(sol, state)

function get_action_probs(sol::SearchSolutions, state::State)
    act = get_action(sol, state)
    return ismissing(act) ? Dict() : Dict(act => 1.0)
end
