# mimi_NICE


### To Run Mimi-NICE One Time

(1) Set your working directory to the src folder.  

`cd("...local_path_to_mimi_NICE/src")`  

(2) Run the file to construct NICE (this will load the construct_nice function).  

`include("nice.jl")`

(3) Construct your model (this will return your model as well as the RICE parameters for convenience).

`m, rice_params = construct_nice()`  

(4) Run your model.  

`run(m)`  

(5) Extract results.  

`m[:nice_welfare, :welfare]`  


### To Optimize Mimi-NICE  
(1) Set your working directory to the src folder.  
`cd("...local_path_to_mimi_NICE/src")`  

(2) Run the file to construct NICE (this will load the construct_nice function and also return 
    a function to create your objective function as well as the rice parameters).  
`include("nice.jl")`  

(3) Construct your objective function for NICE.  
`nice_objective, rice_params = construct_nice_objective()`  

(4) Set up your optimzation (it's just NLopt stuff at this point).  
```
using NLopt
n_objectives = 10 
opt = Opt(:LN_BOBYQA, n_objectives)  
```
Extract RICE backstop price values and index/scale for NICE.  
`backstop_opt_values = maximum(rice_params[:pbacktime], 2)[2:(n_objectives+1)].*1000.0`

Set upper and lower bounds for the regional savings rates.  
 ```
lower_bounds!(opt, zeros(n_objectives))  
upper_bounds!(opt, backstop_opt_values)  
```
Set the objective function to maximize.  
`max_objective!(opt, (x, grad) -> nice_objective(x))`  

Set a maximum time to stop at if things don't converge.  
```
maxtime!(opt, 300)  
ftol_rel!(opt, 0.000000000005)  
```
Set an initial guess for optimization to try.  
`initial_guess = backstop_opt_values  `

(5) Perform the optimization.  
```
(minf,minx,ret) = optimize(opt, initial_guess)  
println(ret)  
minx  
```
