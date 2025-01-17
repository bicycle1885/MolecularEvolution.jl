#Random collection of optimization functions
const invphi = 1/MathConstants.φ
const invphi2 = 1/MathConstants.φ^2

#Goes from [0,1] to [0,inf]
function unit_transform(x::Real; k=1.0)
    (-k*x)/(x-1)
end

#Goes from [0,inf] to [0,1]
function unit_inv_transform(x::Real; k=1.0)
    x/(x+k)
end

"""
Golden section search.

Given a function f with a single local minimum in
the interval [a,b], gss returns a subset interval
[c,d] that contains the minimum with d-c <= tol.

# Examples

```jldoctest
julia> f(x) = -(x-2)^2
f (generic function with 1 method)

julia> m = golden_section_maximize(f, 1, 5, identity, 1e-10)
2.0000000000051843
```

From: https://en.wikipedia.org/wiki/Golden-section_search
"""
function golden_section_maximize(f,a::Real,b::Real,transform,tol::Real)
    a,b=min(a,b),max(a,b)
    h = b - a
    if h <= tol
        return transform((a+b)/2)#(a,b)
    end
    # required steps to achieve tolerance
    n = Int(ceil(log(tol/h)/log(invphi)))
    c = a + invphi2 * h
    d = a + invphi * h
    yc = f(transform(c))
    yd = f(transform(d))
    for k in 1:(n-1)
        if yc > yd
            b = d
            d = c
            yd = yc
            h = invphi*h
            c = a + invphi2 * h
            yc = f(transform(c))
        else
            a = c
            c = d
            yc = yd
            h = invphi*h
            d = a + invphi * h
            yd = f(transform(d))
        end
    end
    if yc > yd
        return transform((a+d)/2)#(a,d)
    else
        return transform((c+b)/2)#(c,b)
    end
end


#This is SGD on trees, sampling branches (using the stochastic_ll_diffs function).
#Promising, but need a LOT of testing. See the FUBAR notebook for a use example.
const param_eps = 1e-6

function stochastic_beam(current_vec,direc,step,construct_model_func,newt,beam_length; branches = 50)
    current_model = construct_model_func(current_vec)
    to_search = [current_vec .+ (direc .* (step*i)) for i in 1:beam_length]
    new_models = [construct_model_func(to_search[i]) for i in 1:beam_length]
    beam = sum(stochastic_ll_diffs(newt, current_model, new_models, branches),dims = 2)[:]
    pos = argmax(beam)
    return to_search[pos],pos==length(to_search) #Returns whether the max was furthest away from the start
end

function stochastic_grad(current_vec,construct_model_func,newt; branches = 50)
    current_model = construct_model_func(current_vec)
    new_models = [construct_model_func(current_vec .+ ((1:length(current_vec) .== p).*param_eps)) for p in 1:length(current_vec)]
    grad = sum(stochastic_ll_diffs(newt, current_model, new_models, branches),dims = 2)[:]
    return grad
end

function treeSGD(current_vec,construct_model_func,newt; branches = 10, step = 0.5, numsteps = 10, verbose = true)
    #Init
    current_model = construct_model_func(current_vec)
    direc = current_vec .* 0.0
    LL = log_likelihood!(newt,current_model)
    felsenstein_down!(newt,current_model)
    vecs = []
    pairs = [(LL,current_vec)]
    #for i in 1:99
    i = 1
    while argmax([p[1] for p in pairs]) > length(pairs) - 5
        grad = stochastic_grad(current_vec,construct_model_func,newt, branches = branches)
        direc = grad ./ sqrt(sum(grad.^2))
        current_vec,flag = stochastic_beam(current_vec,direc,step,construct_model_func,newt,numsteps, branches = branches)
        if flag
            step = step * 1.5
        else
            step = step * 0.75
        end
        if mod(i,10) == 0
            current_model = construct_model_func(current_vec)
            LL = log_likelihood!(newt,current_model)
            push!(pairs,(LL,current_vec))
            if verbose
                println(step,(LL,current_vec))
            end
            if mod(i,20) == 0
                felsenstein_down!(newt,current_model)
            end
        end
        push!(vecs,current_vec)
        i += 1
    end
    mean_vec = mean(vecs[end-50:end])
    current_model = construct_model_func(mean_vec)
    smoothLL = log_likelihood!(newt,current_model)

    best_nonsmooth = argmax([i[1] for i in pairs])
    if smoothLL > pairs[best_nonsmooth][1]
        if verbose
            println("Smooth wins ", (mean_vec,smoothLL))
        end
        return smoothLL,mean_vec
    else
        if verbose
            println("Nonsmooth wins ", pairs[best_nonsmooth])
        end
        return pairs[best_nonsmooth]
    end
end

#This is traditional numerical hill climbing. Likely worse than just using Optim.jl, but maybe useful if we need to customize something?
#Gets parabola for 3 evals
function parabola_fun(xvec,yvec)
    x1,x2,x3 = xvec[1],xvec[2],xvec[3];
    y1,y2,y3 = yvec[1],yvec[2],yvec[3];
    denom = (x1 - x2) * (x1 - x3) * (x2 - x3);
    A     = (x3 * (y2 - y1) + x2 * (y1 - y3) + x1 * (y3 - y2)) / denom;
    B     = (x3*x3 * (y1 - y2) + x2*x2 * (y3 - y1) + x1*x1 * (y2 - y3)) / denom;
    C     = (x2 * x3 * (x2 - x3) * y1 + x3 * x1 * (x3 - x1) * y2 + x1 * x2 * (x1 - x2) * y3) / denom;
    xv = -B / (2*A);
    yv = C - B*B / (4*A);
    return A,B,C #Ax^2 + Bx +C
end

#Not sure if this works when the points aren't ordered.
function line_test(xvec,yvec)
    return yvec[2] > yvec[1] + (xvec[2]-xvec[1])*(((yvec[3]-yvec[1])/(xvec[3]-xvec[1])))
end

#Returns the max point (x-axis) of a parabola.
function new_max(xvec,yvec)
    A,B,C = parabola_fun(xvec,yvec)
    return -B/2A
end

"""
    quadratic_CI(xvec,yvec; rate_conf_level = 0.99)

Takes xvec, a vector of parameter values, and yvec, a vector of log likelihood evaluations
(note: NOT the negative LLs you) might use with Optim.jl. Returns the confidence intervals
computed by a quadratic approximation to the LL.
"""
function quadratic_CI(xvec::Vector,yvec::Vector; rate_conf_level = 0.99)
    if !line_test(xvec,yvec)
        @warn "Confidence intervals might not be trustworthy."
    end

    A,B,C = parabola_fun(xvec,yvec)
    inv_D2 = 1/(-2*A) #inv 2nd deriv of quadratic

    alpha_level = (1 - rate_conf_level)
    tstar = quantile(Normal(0,1), 1 - alpha_level/2)
    CI = tstar*sqrt(inv_D2)
    max_pos = new_max(xvec,yvec)
    lowerCI = max_pos.-CI
    upperCI = max_pos.+CI
    return [lowerCI,max_pos,upperCI]
end

"""
    quadratic_CI(f::Function,opt_params::Vector, param_ind::Int; rate_conf_level = 0.99, nudge_amount = 0.01)

Takes a NEGATIVE log likelihood function (compatible with Optim.jl), a vector of maximizing parameters, an a parameter index.
Returns the quadratic confidence interval.
"""
function quadratic_CI(f::Function,opt_params::Vector, param_ind::Int; rate_conf_level = 0.99, nudge_amount = 0.01)
    nudge_vec = [-nudge_amount,0.0,nudge_amount]
    base_vec = zeros(length(opt_params))
    base_vec[param_ind] = 1.0
    yvec = -[f(opt_params .+ (base_vec.*nudge)) for nudge in nudge_vec]
    xvec = (opt_params[param_ind].+nudge_vec)
    quadratic_CI(xvec,yvec; rate_conf_level = rate_conf_level)
end

function discrete_grad(current_vec,construct_model_func,newt)
    current_model = construct_model_func(current_vec)
    new_models = [construct_model_func(current_vec .+ ((1:length(current_vec) .== p).*param_eps)) for p in 1:length(current_vec)]
    baseLL = log_likelihood!(newt,current_model)
    newLLs = [log_likelihood!(newt,mod) for mod in new_models]
    grad = newLLs .- baseLL
    return grad
end

function beam_search(vec,direc,step,construct_model_func; tree = newt)
    steps = []
    LLs = []
    stepped = 0.0
    for i in 1:3
        mod = construct_model_func(vec .+ (stepped .* direc))
        push!(steps,stepped)
        push!(LLs,log_likelihood!(tree,mod))
        stepped = stepped + step
        step = step * 1.5
    end
    while LLs[end] > LLs[end-1]
        mod = construct_model_func(vec .+ (stepped .* direc))
        push!(steps,stepped)
        push!(LLs,log_likelihood!(tree,mod))
        stepped = stepped + step
        step = step * 1.5
    end
    parab_step = new_max(steps[end-2:end],LLs[end-2:end])
    mod = construct_model_func(vec .+ (parab_step .* direc))
    parab_LL = log_likelihood!(tree,mod)
    if parab_LL > maximum(LLs)
        return parab_LL, vec .+ (parab_step .* direc), length(LLs)
    else
        ind = argmax(LLs)
        return LLs[ind], vec .+ (steps[ind] .* direc), length(LLs)
    end
end

function grad_beam_climb(current_vec,construct_model_func,newt; start_step = 0.1, tol = 0.1, grad_func = discrete_grad, cycle_cap = 50)
    LL = -Inf
    oldLL = -Inf
    diff = 10.0
    count = 1
    while diff > tol && count < cycle_cap
        count += 1

            #grad = discrete_grad(current_vec,construct_model_func,newt)
            #direc = grad ./ sqrt(sum(grad.^2))
            #println(direc)
        grad = grad_func(current_vec,construct_model_func,newt)
        direc = grad ./ sqrt(sum(grad.^2))
            #println(direc)

        LL,current_vec,len = beam_search(current_vec,direc,start_step,construct_model_func, tree = newt)
        if len > 3
            start_step = start_step * 3.0
        else
            start_step = start_step * 0.3
        end
        if diff == Inf
            diff = LL - oldLL
        else
            diff = 0.75(LL - oldLL) + 0.25*diff
        end
        oldLL = LL
        println(LL, ", ", len, ", " ,diff)
    end
    return current_vec,LL
end
