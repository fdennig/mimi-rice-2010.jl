using Mimi

@defcomp nice_welfare begin

    regions = Index()
    quintiles = Index()

    pop = Parameter(index=[time, regions, quintiles]) #quintile population
    quintile_c = Parameter(index=[time, regions, quintiles])# consumption by quintile
    rho = Parameter() # prtp
    eta = Parameter() # elast of MU

    welfare = Variable()  #Total welfare
end

function run_timestep(state::nice_welfare, t::Int)
    v, p, d = getvpd(state)

    if t==1
        v.welfare = sum((p.quintile_c[t,:,:] .^ (1.0 - p.eta)) ./ (1.0 - p.eta) .* p.pop[t,:,:]) / (1.0 + p.rho)^(10*(t-1))
    else
        v.welfare = v.welfare + sum((p.quintile_c[t,:,:] .^ (1.0 - p.eta)) ./ (1.0 - p.eta) .* p.pop[t,:,:]) / (1.0 + p.rho)^(10*(t-1))
    end

end
