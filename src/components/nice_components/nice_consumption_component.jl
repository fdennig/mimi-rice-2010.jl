using Mimi

@defcomp nice_consumption begin

    regions = Index()
    quintiles = Index()

    CPC             = Parameter(index=[time, regions]) # Per capita consumption (thousands 2005 USD per year)
    DAMFRAC         = Parameter(index=[time, regions]) #share of output lost to climate
    ABATEFRAC       = Parameter(index=[time,regions]) #share of output to abatement
    income_dist     = Parameter(index=[regions, quintiles]) # regional income distribution by quintile
    damage_dist     = Parameter(index=[regions, quintiles]) # regional damage dist by quintile
    abatement_dist  = Parameter(index=[regions, quintiles]) # regional abatment dist by quintiles

    quintile_c      = Variable(index=[time, regions, quintiles])# consumption by quintile

end

########################################################################################


function run_timestep(state::nice_consumption, t::Int)
    v, p, d = getvpd(state)


    for r in d.regions
        dam_loss = p.DAMFRAC[t,r] / (1.0 + p.DAMFRAC[t,r]^10)
        net_frac = 1.0 - p.ABATEFRAC[t,r] - dam_loss

        for q in d.quintiles
            v.quintile_c[t,r,q] = max((5.0 * (p.CPC[t,r] / net_frac) * (p.income_dist[r,q] - p.ABATEFRAC[t,r] * p.abatement_dist[r,q] - dam_loss * p.damage_dist[r,q])), 0.0001)
        end
    end
end
