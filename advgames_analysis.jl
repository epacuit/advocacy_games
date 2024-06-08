# Define special data to record

adv_coop(player) = player.adv_type == :C
adv_defect(player) = player.adv_type == :D
should_c(player) = est_move_coop(player) > est_move_defect(player)
should_d(player) = est_move_coop(player) < est_move_defect(player)
should_adv_c(player) = est_adv_coop(player) > est_adv_defect(player)
should_adv_d(player) = est_adv_coop(player) < est_adv_defect(player)

function cum_avg(a::Vector{Float64})  # helper function that returns vector of cumulative averages of vector a
      ca=Float64[]    
      for i in 1:length(a)
          push!( ca, sum(first(a,i))/i )
      end
return ca
end


#individual_incls(model) = [pr_coop(p) for p in allagents(model)]
avg_incl(model) = sum([pr_coop(p) for p in allagents(model)]) / nagents(model)  
 
pr_max_coop(model) = sum([pr_coop(p) == 1.0 for p in allagents(model)]) / nagents(model)
pr_max_defect(model) = sum([pr_coop(p) == 0.0 for p in allagents(model)]) / nagents(model)

cooperate_state(model) = pr_max_coop(model)>.75
defect_state(model) = pr_max_defect(model) >.75

pr_adv_coop(model) = sum([advocate(p) == :C for p in allagents(model)]) / nagents(model)
pr_adv_defect(model) = sum([advocate(p) == :D for p in allagents(model)]) / nagents(model)

pr_hyp_adv_c_play_d(model) = sum([advocate(p) == :C && pr_coop(p) <= 0.15 for p in allagents(model)]) / nagents(model)
pr_hyp_adv_d_play_c(model) = sum([advocate(p) == :D && pr_coop(p) >= 0.85 for p in allagents(model)]) / nagents(model)

avg_pr_max_coop(model) = mean([pr_coop(p) for p in allagents(model)])  >= 0.85
avg_pr_max_defect(model) = mean([pr_coop(p) for p in allagents(model)])  <= 0.15

pr_mistaken_adv(model) = sum([(advocate(p) == :C && est_move_coop(p) < est_move_defect(p)) ||
                              (advocate(p) == :D && est_move_coop(p) > est_move_defect(p))
                            for p in allagents(model)]) / nagents(model)

proportion_should_c(model) = sum([should_c(p) for p in allagents(model)]) / nagents(model)
proportion_should_d(model) = sum([should_d(p) for p in allagents(model)]) / nagents(model)
proportion_should_adv_c(model) = sum([should_adv_c(p) for p in allagents(model)]) / nagents(model)
proportion_should_adv_d(model) = sum([should_adv_d(p) for p in allagents(model)]) / nagents(model)
cc(model) = float(model.payouts[:C, :C])
cd(model) = float(model.payouts[:C, :D])
dc(model) = float(model.payouts[:D, :C])
dd(model) = float(model.payouts[:D, :D])

is_pd(model) = dc(model) > cc(model) > dd(model) > cd(model)
is_chicken(model) = dc(model) > cc(model) && cd(model) > dd(model)
is_sh(model) = cc(model) > dc(model) && dd(model) > cd(model) && cc(model) > dd(model)
is_c_dom(model) = cc(model) > dc(model) && cd(model) > dd(model) && cc(model) > dd(model)
is_d_dom(model) = dd(model) > cd(model) && dc(model) > cc(model) && dd(model) > cc(model)

function game_type(model) 
    if is_pd(model)
        return "PD"
    elseif is_chicken(model)
        return "CH"
    elseif is_sh(model)
        return "SH"
    elseif is_c_dom(model)
        return "Cdom"
    elseif is_d_dom(model)
        return "Ddom"
    else 
        return "Other"
    end
end

cooperative(player) = pr_coop(player) >= (1-player.move_increment)
uncooperative(player) = pr_coop(player) <= player.move_increment

perc_cooperative(model) = sum([cooperative(p) for p in allagents(model)]) / nagents(model)

perc_uncooperative(model) = sum([uncooperative(p) for p in allagents(model)]) / nagents(model)

perc_middle(model) = sum([!cooperative(p) && !uncooperative(p) for p in allagents(model)]) / nagents(model)

variance_inclinations(model) = var([pr_coop(p) for p in allagents(model)])

