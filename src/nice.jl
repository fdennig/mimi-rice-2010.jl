using DataFrames
using NLopt

include(joinpath(dirname(@__FILE__), "components/nice_components/nice_grosseconomy_component.jl"))
include(joinpath(dirname(@__FILE__), "components/nice_components/nice_consumption_component.jl"))
include(joinpath(dirname(@__FILE__), "components/nice_components/nice_welfare_component.jl"))
include(joinpath(dirname(@__FILE__), "rice2010.jl"))
include(joinpath(dirname(@__FILE__), "helpers.jl"))

function construct_nice(nsteps=60, xi=1.0, omega=1.0)


    # Read in income quintile distribution data
    income_dist = Array(readtable(joinpath(dirname(@__FILE__), "../data/income_quintiles_RICE.csv"), header=false))

    # Estimate damage and abatement distributions for quintiles
    damage_dist = quintile_dist(xi, income_dist)
    abatement_dist = quintile_dist(omega, income_dist)

    # Construct RICE2010 and load RICE parameters
    m, rice_params = getrice()

    # Create variable for income quintile populations for each region.
    rice_population = rice_params[:l]
    pop_data = 0.2 .* reshape(repmat(rice_population,1,5), nsteps, 12, 5)

    # Set quintile index
    setindex(m, :quintiles, ["First", "Second", "Third", "Fourth", "Fifth"])

    # Delete gross economy (to allow for full capital deprecation) and RICE welfare component.
    delete!(m, :grosseconomy)
    delete!(m, :welfare)

    # Add NICE specific components.
    addcomponent(m, nice_grosseconomy, before=:emissions)
    addcomponent(m, nice_consumption, after=:neteconomy)
    addcomponent(m, nice_welfare, after=:nice_consumption)

    # Set all model parameters
    setparameter(m, :nice_grosseconomy, :al, rice_params[:al])
    setparameter(m, :nice_grosseconomy, :l, rice_params[:l])
    setparameter(m, :nice_grosseconomy, :gama, rice_params[:gama])
    setparameter(m, :nice_grosseconomy, :dk, rice_params[:dk])
    setparameter(m, :nice_grosseconomy, :k0,  rice_params[:k0])

    setparameter(m, :nice_consumption, :income_dist, transpose(income_dist ./ 100))
    setparameter(m, :nice_consumption, :damage_dist, transpose(damage_dist ./ 100))
    setparameter(m, :nice_consumption, :abatement_dist, transpose(abatement_dist ./ 100))

    setparameter(m, :nice_welfare, :pop, pop_data)
    setparameter(m, :nice_welfare, :rho, 0.015)
    setparameter(m, :nice_welfare, :eta, 1.5)

    # Set new savings rate (base NICE value differs from RICE savings rate)
    setparameter(m, :neteconomy, :S, (ones(nsteps,12) .* 0.2585))

    # Make model component connections.
    connectparameter(m, :nice_grosseconomy, :I, :neteconomy, :I)
    connectparameter(m, :emissions, :YGROSS, :nice_grosseconomy, :YGROSS)
    connectparameter(m, :sealeveldamages, :YGROSS, :nice_grosseconomy, :YGROSS)
    connectparameter(m, :damages, :YGROSS, :nice_grosseconomy, :YGROSS)
    connectparameter(m, :neteconomy, :YGROSS, :nice_grosseconomy, :YGROSS)
    connectparameter(m, :nice_consumption, :CPC, :neteconomy, :CPC)
    connectparameter(m, :nice_consumption, :DAMFRAC, :damages, :DAMFRAC)
    connectparameter(m, :nice_consumption, :ABATEFRAC, :emissions, :ABATEFRAC)
    connectparameter(m, :nice_welfare, :quintile_c, :nice_consumption, :quintile_c)

    return m, rice_params
end


# Create NICE objective function, passing in version of NICE made with "construct_nice()" function.
function construct_nice_objective()

    # Get an implementation of the NICE model
    m, rice_params = construct_nice()

    # Get backstop prices from base version of RICE
    rice_backstop = rice_params[:pbacktime]

    function nice_objective(tax::Array{Float64,1})

        # Calculate emissions abatement level as a function of the carbon tax.
        abatement_level = mu_from_tax(tax, rice_backstop, 2.8)

        setparameter(m, :emissions, :MIU, abatement_level)
        run(m)
        return m[:nice_welfare, :welfare]
    end

    return nice_objective, rice_params
end
