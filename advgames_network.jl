using Agents
using Parameters
using Statistics: mean
using Random



## Players
@with_kw mutable struct Player <: AbstractAgent
    
    id::Int # the player's unique id
    pos::NTuple{2,Int} # the position of the player in the grid
    
    # the actions available to the player in the game
    acts::Vector{Symbol} = [:C, :D] 
    
    # each player maintains their own payouts of the game
    payouts::Dict{Tuple{Symbol, Symbol}, Float64}

    # parameters used to maintain the player's inclinations
    inclinations::Dict{Symbol, Float64} # mixed strategy 
    act_est::Dict{Symbol, Float64} # weighted average returns for each strategy
    weight_of_present_for_move::Float64 = 0.2 # weight of current payout when updating act estimates
    move_increment::Float64 = 0.15 # used to change inclination
    move_mutation_rate::Float64 = 0.15 # probability the move mutates (i.e., the probability of a tremble)
    
    # parameters used to maintain the player's advocacy type
    adv_type::Symbol # the pure strategy representing what the player advocates
    adv_est::Dict{Symbol, Float64}  # (weighted) average returns for each advocacy type
    weight_of_present_for_adv::Float64 = 0.3 # weight of current payout when updating adv estimates
    adv_mutation_rate::Float64 = 0.2 # probability that the advocacy type mutates when changing advocacy type 
    
    tolerance::Float64 = 0.05 # only react if the difference between the estimates is greater than tolerance
    
    # parameters to keep track of 
    total_payout::Float64 = 0 # total payout during a simulation
    num_moves::Int64 = 0 # number of times a player moves in a simulation
    num_adv_mutations::Int64 = 0 # number of times the advocacy type mutates
end

# define some helper functions 
flip(bias) = rand() < bias # returns true with probability bias
other_act(act) = act != :C ? :C : :D

# functions that make it easier to record information about the players in a simulation
advocate(player) = player.adv_type

inc_coop(player) = player.inclinations[:C]
pr_coop(player) = inc_coop(player)

inc_defect(player) = player.inclinations[:D]
pr_defect(player) = inc_defect(player)

est_move_coop(player) = player.act_est[:C]
est_move_defect(player) = player.act_est[:D]
est_adv_coop(player) = player.adv_est[:C]
est_adv_defect(player) = player.adv_est[:D]
utility_adv_coop(player) = est_adv_coop(player)  - est_adv_defect(player) 
utility_inc_coop(player) = est_move_coop(player)  - est_move_defect(player) 

# using inclinations, randomly select an act, and mutate with probability move_mutation_rate
function move(player)
    tentative_move = sample(player.acts, Weights([player.inclinations[a] for a in player.acts]), 1)[1]
    return flip(player.move_mutation_rate) ? other_act(tentative_move) : tentative_move
end

# update total payouts and number of moves
update_total_payout!(player, payout) = player.total_payout += payout
update_num_moves!(player) = player.num_moves += 1

# update act/advocate estimates
update_act_estimate!(player, payout, move) = player.act_est[move] = player.weight_of_present_for_move * payout + (1-player.weight_of_present_for_move) * player.act_est[move]

update_adv_estimate!(player, payout, adv) = player.adv_est[adv] = player.weight_of_present_for_adv * payout + (1-player.weight_of_present_for_adv) * player.adv_est[adv]

function update_estimates!(player, payout, move, adv)
    update_act_estimate!(player, payout, move)
    update_adv_estimate!(player, payout, adv)
    return player
end

# update advocacy type
function update_advocate_type!(player)

    # change the advocacy type if the other act has a larger estimated payout
    if((player.adv_est[:C] - player.adv_est[:D]) >= player.tolerance)
        player.adv_type = :C
    elseif((player.adv_est[:D] - player.adv_est[:C]) > player.tolerance)
        player.adv_type = :D
    end

    # with small mutation, advocate for something different
    if flip(player.adv_mutation_rate)
        player.num_adv_mutations += 1
        player.adv_type = other_act(player.adv_type) 
    end
    return
end

# update the players' inclinations
function update_inclinations!(player) 
    if abs(player.act_est[:C] - player.act_est[:D]) > player.tolerance
        # change the inclination for C in the direction of the difference of estimates between C and D
        inc_for_C = player.inclinations[:C] + (player.act_est[:C] - player.act_est[:D]) * player.move_increment
        
        if inc_for_C > 1
            player.inclinations[:C] = 1
            player.inclinations[:D] = 0
        elseif inc_for_C < 0
            player.inclinations[:C] = 0
            player.inclinations[:D] = 1
        else
            player.inclinations[:C] = inc_for_C
            player.inclinations[:D] = 1 - inc_for_C
        end
    end
    return
end


## Update Game

# the number advocating act from a set of players
num_advocating(players, act) = length([a for a in players if a.adv_type == act])

# update current game.  
function update_game!(model, player) 
    
    if model.influence_type == :local
        peers = nearby_agents(player, model)
        num_peers = length(collect(peers))
    elseif model.influence_type == :global
        peers = allagents(model)
        num_peers = nagents(model)
    end

    # find proporitions of players advocating C and advocating D
    proportion_adv_C = num_advocating(peers, :C) / num_peers
    proportion_adv_D = num_advocating(peers, :D) / num_peers
       
    # determine the positive and negative pressure
    pos_pressure = proportion_adv_C > 0.5 ? model.max_pos_pressure * (2 * proportion_adv_C -1) : model.max_pos_pressure * (2 * proportion_adv_D - 1)
    neg_pressure =  proportion_adv_C > 0.5 ? model.max_neg_pressure * (2 * proportion_adv_C -1) : model.max_neg_pressure * (2 * proportion_adv_D - 1)
    
    # the new payouts are calculated by applying the pressures to the base game
    if proportion_adv_C > 0.5
        new_payouts = Dict(
            (:C, :C) => model.base_payouts[:C, :C] + pos_pressure,
            (:C, :D) => model.base_payouts[:C, :D] + pos_pressure,
            (:D, :C) => model.base_payouts[:D, :C] - neg_pressure,
            (:D, :D) => model.base_payouts[:D, :D] - neg_pressure,
        )
    else
        new_payouts = Dict(
            (:C, :C) => model.base_payouts[:C, :C] - neg_pressure,
            (:C, :D) => model.base_payouts[:C, :D] - neg_pressure,
            (:D, :C) => model.base_payouts[:D, :C] + pos_pressure,
            (:D, :D) => model.base_payouts[:D, :D] + pos_pressure,
        )
    end
    
    if model.influence_type == :local 
        player.payouts = new_payouts
    elseif model.influence_type == :global
        model.payouts = new_payouts
    end
end

## Model Step

function model_step!(model)
    # choose a random player 

    if model.interaction_type == :local
        p1 = sample(collect(allagents(model)), replace=false, 1)[1]
        p2 = sample(collect(nearby_agents(p1, model)), replace=false, 1)[1]
    elseif model.interaction_type == :global
        p1, p2 = sample(collect(allagents(model)), replace=false, 2)
    end

    p1_move = move(p1)
    p2_move = move(p2)
    
    if model.influence_type == :local
        p1_payout = p1.payouts[p1_move, p2_move]
        p2_payout = p2.payouts[p2_move, p1_move]
    elseif model.influence_type == :global
        p1_payout = model.payouts[p1_move, p2_move]
        p2_payout = model.payouts[p2_move, p1_move]
    end
    
    p1_adv = advocate(p1)
    p2_adv = advocate(p2)
    
    update_total_payout!(p1, p1_payout)
    update_total_payout!(p2, p2_payout)
    update_num_moves!(p1)
    update_num_moves!(p2)
    
    update_estimates!(p1, p1_payout, p1_move, p1_adv)
    update_estimates!(p2, p2_payout, p2_move, p2_adv)

    p1_did_update_inc = false
    p1_did_update_adv = false
    p2_did_update_inc = false
    p2_did_update_adv = false
        
    if flip(model.adv_reassess_frequency) 
        update_advocate_type!(p1) 
        p1_did_update_adv = advocate(p1) != p1_adv
    end

    if flip(model.adv_reassess_frequency)
        update_advocate_type!(p2) 
        p2_did_update_adv = advocate(p2) != p2_adv
    end

    if flip(model.move_reassess_frequency)
        update_inclinations!(p1)
        p1_did_update_inc = true
    end
                
    if flip(model.move_reassess_frequency)
        update_inclinations!(p2)
        p2_did_update_inc = true
    end

    # record the current probabilities to cooperate

    model.prs_coop[p1.pos[1], p1.pos[2]] = inc_coop(p1)
    model.prs_coop[p2.pos[1], p2.pos[2]] = inc_coop(p2)
            
    if p1_did_update_adv || p2_did_update_adv || p1_did_update_inc || p2_did_update_inc

        if model.influence_type == :local
            update_game!(model, p1)
            update_game!(model, p2)
        elseif model.influence_type == :global
            update_game!(model, p1) # only need to update the game once (the game is the same for all players)
        end
    end
end
        
## Initialize

generate_payouts(R, S, T, P) = Dict((:C, :C) => R, (:C, :D) => S, (:D, :C) => T, (:D, :D) => P)

function initialize(; 
    pr_cooperator = 0.5, 
    init_pr_coop_for_cooperator = 0.75, 
    pr_defector = 0.5, 
    init_pr_coop_for_defector = 0.25, 
    pr_neutral = 0.0,
    dims = (5, 5),
    influence_type = :global,
    interaction_type = :global,
    rstp = nothing,
    payouts = Dict(
        (:C, :C) => 3, 
        (:C, :D) => 0, 
        (:D, :C) => 5, 
        (:D, :D) => 1), 
    adv_reassess_frequency = 0.03, 
    move_reassess_frequency = 0.1,
    max_pos_pressure = 6, 
    max_neg_pressure = 6,
    move_increment = 0.15,
    tolerance = 0.0,
    weight_of_present_for_move = 0.2,
    weight_of_present_for_adv = 0.3,
    adv_mutation_rate = 0.02,
    move_mutation_rate = 0.15,
)

    base_payouts = rstp === nothing ? payouts : generate_payouts(rstp[1], rstp[2], rstp[3], rstp[4])

    numagents = dims[1] * dims[2]

    pr_cooperator = pr_cooperator / (pr_cooperator + pr_defector + pr_neutral)

    pr_defector = pr_defector / (pr_cooperator + pr_defector + pr_neutral)

    pr_neutral = pr_neutral / (pr_cooperator + pr_defector + pr_neutral)

    properties = Dict(  
        :payouts => base_payouts,
        :base_payouts => base_payouts,
        :adv_reassess_frequency => adv_reassess_frequency,
        :move_reassess_frequency => move_reassess_frequency,
        :max_pos_pressure =>  max_pos_pressure,
        :max_neg_pressure =>  max_neg_pressure,
        :interaction_type => interaction_type,
        :influence_type => influence_type,
        :prs_coop =>  zeros(dims)
    )

    parameters = Dict{Symbol, Any}(     
        :base_payouts => [base_payouts[(:D,:C)],base_payouts[(:C,:C)],base_payouts[(:D,:D)],base_payouts[(:C,:D)]],
        :numagents => numagents,
        :dims => dims,
        :pr_cooperator => pr_cooperator,
        :pr_defector => pr_defector,
        :pr_neutral => pr_neutral,
        :population => numagents,
        :influence_type => influence_type,
        :interaction_type => interaction_type,
        :a_m_reassess_frequencies => [adv_reassess_frequency, move_reassess_frequency],
        :max_pos_neg_pressures =>  [max_pos_pressure, max_neg_pressure],
        :a_m_mutation_rates => [adv_mutation_rate,move_mutation_rate], 
        :a_m_weights_of_present => [weight_of_present_for_adv, weight_of_present_for_move],
        :tolerance => tolerance,
        :m_increment => move_increment
    )

    space = GridSpaceSingle(dims; periodic = true)

    model = ABM(Player, space; properties = properties)

    player_types = sample([:cooperator, :defector, :neutral], Weights([pr_cooperator, pr_defector, pr_neutral]), numagents)

    for pid in 1:numagents

        player_type = player_types[pid]
        if player_type == :cooperator
            p = Player(
                id=pid, 
                pos=(1,1),
                acts=[:C, :D], 
                adv_type=:C, 
                payouts = base_payouts,
                inclinations = Dict(:C=>init_pr_coop_for_cooperator, :D=>1 - init_pr_coop_for_cooperator), 
                act_est = Dict(
                    :C=> mean([base_payouts[:C, :C], base_payouts[:C, :D], base_payouts[:D, :C], base_payouts[:D, :D]]),
                    :D=> mean([base_payouts[:C, :C], base_payouts[:C, :D], base_payouts[:D, :C], base_payouts[:D, :D]])),
                adv_est = Dict(
                    :C=> mean([base_payouts[:C, :C], base_payouts[:C, :D], base_payouts[:D, :C], base_payouts[:D, :D]]),
                    :D=> mean([base_payouts[:C, :C], base_payouts[:C, :D], base_payouts[:D, :C], base_payouts[:D, :D]])),
                move_increment  = move_increment,
                tolerance = tolerance,
                adv_mutation_rate = adv_mutation_rate,
                weight_of_present_for_move = weight_of_present_for_move,
                weight_of_present_for_adv = weight_of_present_for_adv,
                move_mutation_rate = move_mutation_rate)
            add_agent_single!(p, model)
            model.prs_coop[p.pos[1], p.pos[2]] = init_pr_coop_for_cooperator
        elseif player_type == :defector
            p = Player(
                id=pid, 
                pos=(1,1),
                acts=[:C, :D], 
                adv_type=:D, 
                payouts = base_payouts,
                inclinations = Dict(:C=>init_pr_coop_for_defector, :D=>1 - init_pr_coop_for_defector), 
                act_est = Dict(
                    :C=> mean([base_payouts[:C, :C], base_payouts[:C, :D], base_payouts[:D, :C], base_payouts[:D, :D]]),
                    :D=> mean([base_payouts[:C, :C], base_payouts[:C, :D], base_payouts[:D, :C], base_payouts[:D, :D]])),
                adv_est = Dict(
                    :C=> mean([base_payouts[:C, :C], base_payouts[:C, :D], base_payouts[:D, :C], base_payouts[:D, :D]]),
                    :D=> mean([base_payouts[:C, :C], base_payouts[:C, :D], base_payouts[:D, :C], base_payouts[:D, :D]])),
                move_increment  = move_increment,
                tolerance = tolerance,
                adv_mutation_rate = adv_mutation_rate,
                weight_of_present_for_move  = weight_of_present_for_move,
                weight_of_present_for_adv  = weight_of_present_for_adv,
                move_mutation_rate = move_mutation_rate)
            add_agent_single!(p, model)
            model.prs_coop[p.pos[1], p.pos[2]] = init_pr_coop_for_defector

        elseif player_type == :neutral
            p = Player(
                id=pid, 
                pos=(1,1),
                acts=[:C, :D], 
                adv_type= flip(0.5) ? :C : :D, 
                payouts = base_payouts,
                inclinations = Dict(:C=>0.5, :D=>0.5), 
                act_est = Dict(
                    :C=> mean([base_payouts[:C, :C], base_payouts[:C, :D], base_payouts[:D, :C], base_payouts[:D, :D]]),
                    :D=> mean([base_payouts[:C, :C], base_payouts[:C, :D], base_payouts[:D, :C], base_payouts[:D, :D]])),
                adv_est = Dict(
                    :C=> mean([base_payouts[:C, :C], base_payouts[:C, :D], base_payouts[:D, :C], base_payouts[:D, :D]]),
                    :D=> mean([base_payouts[:C, :C], base_payouts[:C, :D], base_payouts[:D, :C], base_payouts[:D, :D]])),
                move_increment  = move_increment,
                tolerance = tolerance,
                adv_mutation_rate = adv_mutation_rate,
                weight_of_present_for_move  = weight_of_present_for_move,
                weight_of_present_for_adv  = weight_of_present_for_adv,
                move_mutation_rate = move_mutation_rate)
            add_agent_single!(p, model)
            model.prs_coop[p.pos[1], p.pos[2]] = 0.5
        end
    end
    return model, parameters
end
