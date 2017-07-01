#################################################################################
# CUSTOM TYPES
#################################################################################

# Type to hold specifications for running NICE.
type NICE_inputs{}
    nsteps::Int64
    xi::Float64
    omega::Float64
    cap_dep::Array{Float64, 1}
    rho::Float64
    eta::Float64
    abate::Array{Float64, 2}
end

# Type to hold output from NICE.
type NICE_outputs{}
    nice_inputs::NICE_inputs
    tax::Array{Float64, 1}
    temperature::Array{Float64, 1}
    mitigation::Array{Float64, 2}
    emissions::Array{Float64, 1}
    consumption::Array{Float64, 3}
    model::Mimi.Model
end


#################################################################################
# HELPER FUNCTIONS
#################################################################################

function getindexfromyear_rice_2010(year)
    const baseyear = 2005

    if rem(year - baseyear, 10) != 0
        error("Invalid year")
    end

    return div(year - baseyear, 10) + 1
end

#Function to read a single parameter value from original RICE 2010 model.
function getparam_single(f, range::AbstractString, regions)
    vals= Array(Float64,length(regions))
    for (i,r) = enumerate(regions)
        data=readxl(f,"$r\!$range")
        vals[i]=data[1]
    end
    return vals
end

#Function to read a time series of parameter values from original RICE 2010 model.
function getparam_timeseries(f, range::AbstractString, regions, T)
    vals= Array(Float64, T, length(regions))
    for (i,r) = enumerate(regions)
        data=readxl(f,"$r\!$range")
        for n=1:T
            vals[n,i] = data[n]
        end
    end
    return vals
end


#Function to calculate quintile distributions.
function quintile_dist(elast, income_d)
    value = income_d .^ elast
     for r in 1:12
        value[:,r] = value[:,r] ./ sum(value[:,r])
    end
    return value .* 100
end


#Function to calculate emissions control rate as a function of the carbon tax.
function mu_from_tax(tax::Array{Float64,1}, backstop_p::Array{Float64,2}, theta2::Float64)
    backstop = backstop_p .* 1000.0
    pbmax = maximum(backstop, 2)
    TAX = [0.0; pbmax[2:end]]
    TAX[2:(length(tax)+1)] = tax
    mu = min((max(((TAX ./ backstop) .^ (1 / (theta2 - 1.0))), 0.0)), 1.0)

    return mu, TAX
end




function deterministic_nice(m::Mimi.Model)
    run(m)
    result = NICE_outputs(inputs, zeros(getindexcount(m, :time)), m[:climatedynamics, :TATM],  m[:emissions, :MIU], m[:emissions, :E], m[:nice_consumption, :quintile_c], m)

    return result
end


function optimize_nice(objetive_function, m::Mimi.Model, algorithm::Symbol, n_objectives::Int64, upperbound::Array{Float64,1}, stop_time::Int64, tolerance::Float64, theta2::Float64, backstop_price::Array{Float64,2})
    opt = Opt(algorithm, n_objectives)

    lower_bounds!(opt, zeros(n_objectives))
    upper_bounds!(opt, upperbound)

    max_objective!(opt, (x, grad) -> objetive_function(x))

    maxtime!(opt, stop_time)
    ftol_rel!(opt, tolerance)

    (minf,minx,ret) = optimize(opt, (upperbound .* 0.5))
    println("Convergence result: ", ret)

    mitigation, tax = mu_from_tax(minx, backstop_price, theta2)

    setparameter(m, :emissions, :MIU, mitigation)
    run(m)

    result = NICE_outputs(inputs, tax, m[:climatedynamics, :TATM], mitigation, m[:emissions, :E], m[:nice_consumption, :quintile_c], m)
    return result
end



function region_plot(data, periods, x_title, y_title, main_title, y_max, output_directory, filename)
    R"""

    data = $data
    years = seq(2005, (2005 + (($periods-1)*5)), by=5)
    colors = c("blue", "red", "green", "yellow", "gray", "black", "darkorange", "darkorchid", "gold", "deepskyblue", "limegreen", "palevioletred")

    png(filename = paste($output_directory, $filename, sep="/"), type="cairo", units="in", width=9.5, height=6.5, res=300)
        par(mar=c(5.1, 4.1, 4.1, 8.1), xpd=NA)
        plot(years, data[,1], type="l", lwd=2, col=colors[1], ylim=c(0, $y_max), main=$main_title, xlab = $x_title, ylab= $y_title)
        for(i in 2:ncol(data)){
            lines(years, data[,i], col=colors[i], lwd=2)
        }
        legend("topright", inset=c(-0.2,0), legend=c("US","EU", "Japan", "Russia", "Eurasia", "China", "India", "MidEast", "Africa", "LatAm", "OHI", "OthAsia"), col=colors, title="NICE Region", lwd=2, lty=1)
    dev.off()
    """
end



function global_plot(data, periods, x_title, y_title, main_title, output_directory, filename)
    R"""

    data = $data
    years = seq(2005, (2005 + (($periods-1)*5)), by=5)

    png(filename = paste($output_directory, $filename, sep="/"), type="cairo", units="in", width=9.5, height=6.5, res=300)
        plot(years, data, type="l", lwd=2, col="blue", ylim=c(0, max(data)), main=$main_title, xlab = $x_title, ylab= $y_title)

    dev.off()
    """
end
