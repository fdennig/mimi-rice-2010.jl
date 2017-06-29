# Load required packages.
using NLopt
using Mimi
using JLD
using HDF5
using RCall

#Include helper functions and all model source code.
include(joinpath(dirname(@__FILE__), "helpers.jl"))
include(joinpath(dirname(@__FILE__), "nice.jl"))


####################################################################################################
# NICE PARAMETERS TO CHANGE
####################################################################################################

# The number of time periods to run the model for (defaults to 60).
nsteps = 60

# Income elasticity of damages.
xi = 1.0

# Income elasticity of abatement costs.
omega = 1.0

# Regional capital depreciation rates (defaults to 1.0 for full depreciation).
# Values less than 1.0 use RICE capital accumulation formula.
cap_dep = ones(12)

# Pure rate of time preference
rho = 0.015

# Elasticity of marginal utility.
eta = 1.5

# Regional emissions control rate (only set if not optimizing model).
co2_abatement = zeros(nsteps, 12)

# Exponent of cost control function
theta2 = 2.8

####################################################################################################
# CHOICES ABOUT YOUR ANALYSIS
####################################################################################################

# Do you want to optimze NICE (if false, a deterministic run will be performed).
optimization = true

# Do you want to save your results (true = save results)?
save_results = true

# Name of folder to store your results in (a folder will be created with this name).
results_folder = "test_run"


####################################################################################################
# OPTIMIZATION SETTINGS
####################################################################################################

# Number of objectives (corresponding to how many periods in NICE to optimze over).
n_objective = 10

#Optimization algorithm (:symbol). See options at http://ab-initio.mit.edu/wiki/index.php/NLopt_Algorithms
opt_algorithm = :LN_BOBYQA

# Maximum time in seconds to run (in case things don't converge).
stop_time = 300

# Relative tolerance criteria for convergence (will stop if |Δf| / |f| is less than tolerance
# from one iteration to the next.)
tolerance = 5e-12



####################################################################################################
####################################################################################################
# RUN EVERYTHING
####################################################################################################
####################################################################################################


# Create an instance of custom type `NICE_inputs` to run for a particular specification of the model.
inputs = NICE_inputs(nsteps, xi, omega, cap_dep, rho, eta, co2_abatement)


####################################################################################################
# Optimization Run.
####################################################################################################
if optimization

    # Create a NICE objective function specific to the user parameter settings.
    nice_objective, m, rice_params = construct_nice_objective(inputs)

    #Extract RICE backstop price values and index/scale for NICE (used in optimization).
    backstop_opt_values = maximum(rice_params[:pbacktime], 2)[2:(n_objective+1)].*1000.0

    # Optimize NICE and save the results as a custom type `NICE_outputs`.
    results = optimize_nice(nice_objective, m, opt_algorithm, n_objective, backstop_opt_values, stop_time, tolerance, theta2, rice_params[:pbacktime])


####################################################################################################
# Deterministic Run.
####################################################################################################
else
    m, rice_params = construct_nice(inputs)
    results = deterministic_nice(m)
end


####################################################################################################
# Save Results and Plots.
####################################################################################################
if save_results

    # Create a directory based on user supplied directory name to save results.
    output_directory = joinpath(dirname(@__FILE__), "../results", results_folder)
    mkdir(output_directory)

    # Save model results (this will be the custom type "NICE_output" defined in helpers.jl).
    save(joinpath(output_directory, "results.jld"), "results", results)

    # Save plots for temperature anomaly, total emissions, co2 mitigation, and quintile consumption.
    global_plot(results.temperature, nsteps, "Year", "Degrees C",  "Temperature Increase Above Pre-Industrial", output_directory, "plot_temperature.png")
    global_plot(results.emissions, nsteps, "Year", "Gigatonnes Carbon", "Annual Carbon Emissions", output_directory, "plot_emissions.png")
    region_plot(results.mitigation, nsteps, "Year", "Emission Reduction Share", "Carbon Mitigation Pathways", 1.0, output_directory, "plot_mitigation.png")
    region_plot(results.consumption[:,:,1], nsteps, "Year", "Consumption Level (\$)",  "Regional Consumption: Quintile 1", maximum(results.consumption), output_directory, "plot_quintile_1.png")
    region_plot(results.consumption[:,:,2], nsteps, "Year", "Consumption Level (\$)",  "Regional Consumption: Quintile 2", maximum(results.consumption), output_directory, "plot_quintile_2.png")
    region_plot(results.consumption[:,:,3], nsteps, "Year", "Consumption Level (\$)",  "Regional Consumption: Quintile 3", maximum(results.consumption), output_directory, "plot_quintile_3.png")
    region_plot(results.consumption[:,:,4], nsteps, "Year", "Consumption Level (\$)",  "Regional Consumption: Quintile 4", maximum(results.consumption), output_directory, "plot_quintile_4.png")
    region_plot(results.consumption[:,:,5], nsteps, "Year", "Consumption Level (\$)",  "Regional Consumption: Quintile 5", maximum(results.consumption), output_directory, "plot_quintile_5.png")

    # Save model output (a custom type) using the JLD package.
    save(joinpath(output_directory,"results.jld"), "results", results)

    # Save model run specifications as a .txt file.
    parameter_details = string("nsteps = ", nsteps,
                               "\r\nxi =  ", xi,
                               "\r\nomega = ", omega,
                               "\r\ncap_dep = ", cap_dep,
                               "\r\nrho = ", rho,
                               "\r\neta = ", eta,
                               "\r\noptimze = ", optimize,
                               "\r\noptimization algorithm = ", opt_algorithm,
                               "\r\nnumber of objectives = ", n_objective)
    write(joinpath(output_directory, "Model Specifications.txt"), parameter_details)
end
