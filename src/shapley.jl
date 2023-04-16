
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

dda_shapley_model = function(conversion_path_df; include_heuristics = true)
    paths_vec = conversion_path_df.path
    conv_counts_vec = conversion_path_df.total_conversions
    drop_counts_vec = conversion_path_df.total_null

    state_mapping_dict = dda_mapping(conversion_path_df)

    unique_sates_vec = [k for k in keys(state_mapping_dict) if !(k in ["(conv)", "(drop)", "(start)"])]

    coalitions_vec = get_coalitions(unique_sates_vec)
    permutations_vec = get_permutations(unique_sates_vec)
    cr_dict = get_coalition_conversion_rates_dict(coalitions_vec, paths_vec, conv_counts_vec, drop_counts_vec)
    values_dict = get_values_dict(coalitions_vec, cr_dict)
    shapley_df = get_shapley_values(state_mapping_dict, permutations_vec, values_dict)
    conversions_df = get_shapley_conversions(shapley_df, conv_counts_vec)

    if include_heuristics
        paths_vec = join.(paths_vec,">")
        heuristics_df = heuristics(paths_vec, conv_counts_vec, state_mapping_dict)
        conversions_df = vcat(conversions_df, heuristics_df)
    end
  
    return conversions_df
  end