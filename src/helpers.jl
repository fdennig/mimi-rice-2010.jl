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
end
