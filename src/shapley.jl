
"""
get_coalitions
"""
get_coalitions = function(UniqueSates)
    coalitions = [p for p in combinations(UniqueSates)]

    return coalitions
end

"""
get_coalition_conversion_rates_dict
"""
get_coalition_conversion_rates_dict = function(coalitions, paths, convs, non_convs)
    cr_dict = Dict()
    for i in ProgressBar(eachindex(coalitions))
        cix = [p ⊆ coalitions[i] for p in paths]
        sc = sum(convs[cix])
        snc = sum(non_convs[cix])
        r = sc/(sc + snc)
        push!(cr_dict,  Set(coalitions[i]) => r)
    end

    return cr_dict
end

"""
get_values_dict
"""
get_values_dict = function(coalitions, cr_dict)
    values_dict = Dict()
    for i in eachindex(coalitions)
        ls = [length(p) for p in combinations(coalitions[i])]
        crs = [cr_dict[Set(p)] for p in combinations(coalitions[i])]
        v = sum(crs .* sqrt.(ls ./ sum(ls)))
        push!(values_dict, Set(coalitions[i]) => v)
    end

    return values_dict
end

"""
get_permutations
"""
get_permutations = function(UniqueSates)
    perms = [o for o in permutations(UniqueSates)]

    return perms
end

"""
get_shapley_values
"""
get_shapley_values = function(state_mapping_dict, perms, values_dict)
    shapley_values = []

    UniqueSates = [k for k in keys(state_mapping_dict) if k ∉ ["(conv)", "(drop)", "(start)"]]

    for tactic in UniqueSates
        mvs = []
        for i in eachindex(perms)
            #println(perms[i])
            perm = perms[i]
            position = findfirst(x -> x == tactic, perm)
            sub_with = Set(perm[begin:position])
            sub_without = Set(perm[begin:(position-1)])
            vwith = values_dict[sub_with] 
            if length(sub_without) == 0
            mv = vwith
            elseif vwith >= values_dict[sub_without]
            mv = vwith - values_dict[sub_without]
            else 
            mv = 0
            end
            push!(mvs, mv)
        end
        push!(shapley_values, (tid = state_mapping_dict[tactic] ,tactic = tactic, shapley_value = mean(mvs)))
    end
    ShapleyValues = DataFrame(shapley_values)

    return ShapleyValues
end

"""
get_shapley_conversions
"""
get_shapley_conversions = function(shapley_values, convs)
    shapley_values.Conversions = sum(convs) .* shapley_values.shapley_value ./ sum(shapley_values.shapley_value)
    shapley_values.Touchpoint = shapley_values.tactic
    shapley_values.Model .= "Shapley" 
    Shapley = shapley_values[:,[:tid, :Touchpoint, :Conversions, :Model]]

    return Shapley
end