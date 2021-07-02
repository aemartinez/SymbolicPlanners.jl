export ForwardPlanner, BestFirstPlanner, UniformCostPlanner, GreedyPlanner
export AStarPlanner, WeightedAStarPlanner

"Forward best-first search planner."
@kwdef mutable struct ForwardPlanner <: Planner
    heuristic::Heuristic = GoalCountHeuristic()
    g_mult::Float64 = 1.0 # Path cost multiplier
    h_mult::Float64 = 1.0 # Heuristic multiplier
    max_nodes::Int = typemax(Int)
    save_search::Bool = false # Flag to save search info
end

"Best-first search planner (alias for `ForwardPlanner`)."
BestFirstPlanner(args...; kwargs...) =
    ForwardPlanner(args...; kwargs...)

"Uniform-cost search."
UniformCostPlanner(;kwargs...) =
    ForwardPlanner(;heuristic=NullHeuristic(), h_mult=0, kwargs...)

"Greedy best-first search, with cycle checking."
GreedyPlanner(heuristic::Heuristic; kwargs...) =
    ForwardPlanner(;heuristic=heuristic, g_mult=0, kwargs...)

"A* search."
AStarPlanner(heuristic::Heuristic; kwargs...) =
    ForwardPlanner(;heuristic=heuristic, kwargs...)

"Weighted A* search."
WeightedAStarPlanner(heuristic::Heuristic, h_mult::Real; kwargs...) =
    ForwardPlanner(;heuristic=heuristic, h_mult=h_mult, kwargs...)

function solve(planner::ForwardPlanner,
               domain::Domain, state::State, goal_spec::GoalSpec)
    @unpack h_mult, heuristic, save_search = planner
    # Initialize search tree and priority queue
    node_id = hash(state)
    search_tree = SearchTree(node_id => SearchNode(node_id, state, 0))
    est_cost = h_mult * heuristic(domain, state, goal_spec)
    queue = PriorityQueue{UInt,Float64}(node_id => est_cost)
    # Run the search
    status, node_id = search!(planner, domain, goal_spec, search_tree, queue)
    # Reconstruct plan and return solution
    if status != :failure
        plan, traj = reconstruct(node_id, search_tree)
        if save_search
            return OrderedSearchSolution(status, plan, traj, search_tree, queue)
        else
            return OrderedSearchSolution(status, plan, traj)
        end
    elseif save_search
        return OrderedSearchSolution(status, [], [], search_tree, queue)
    else
        return NullSolution()
    end
end

function search!(planner::ForwardPlanner,
                 domain::Domain, goal_spec::GoalSpec,
                 search_tree::SearchTree, queue::PriorityQueue)
    count = 1
    while length(queue) > 0
        # Get state with lowest estimated cost to goal
        node_id = dequeue!(queue)
        node = search_tree[node_id]
        # Return status and current state if search terminates
        if satisfy(goal_spec.goals, node.state, domain)[1]
            return :success, node_id # Goal reached
        elseif count >= planner.max_nodes
            return :max_nodes, node_id # Node budget reached
        end
        count += 1
        # Expand current node
        expand!(planner, node, search_tree, queue, domain, goal_spec)
    end
    return :failure, nothing
end

function expand!(planner::ForwardPlanner, node::SearchNode,
                 search_tree::SearchTree, queue::PriorityQueue,
                 domain::Domain, goal_spec::GoalSpec)
    @unpack g_mult, h_mult, heuristic = planner
    @unpack metric, constraints = goal_spec
    state = node.state
    # Iterate over available actions
    actions = available(state, domain)
    for act in actions
        # Execute action and trigger all post-action events
        next_state = transition(domain, state, act; check=false)
        next_id = hash(next_state)
        # Check if next state satisfies trajectory constraints
        if !isempty(constraints) && !next_state[domain, constraints]
            continue end
        # Compute path cost
        act_cost = metric == nothing ? 1 :
            next_state[domain, metric] - state[domain, metric]
        path_cost = node.path_cost + act_cost
        # Update path costs if new path is shorter
        next_node = get!(search_tree, next_id,
                         SearchNode(next_id, next_state, Inf))
        cost_diff = next_node.path_cost - path_cost
        if cost_diff > 0
            next_node.parent_id = node.id
            next_node.parent_action = act
            next_node.path_cost = path_cost
            # Update estimated cost from next state to goal
            if !(next_id in keys(queue))
                g_val = g_mult * path_cost
                h_val = h_mult * heuristic(domain, next_state, goal_spec)
                enqueue!(queue, next_id, g_val + h_val)
            else
                queue[next_id] -= cost_diff
            end
        end
    end
end
