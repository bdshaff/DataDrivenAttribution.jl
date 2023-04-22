

dda_logistic_model = function(path_df; include_heuristics = true)

    state_mapping_dict = dda_mapping(path_df)
    unique_states = dda_touchpoints(path_df)
    paths = path_df.path

    X = [u in p for p in paths, u in unique_states]
    y = path_df.conv .== "1"

    glm_fit = glm(X, y, Poisson())
    coeffs = exp.(coef(glm_fit))
    attr_weights = coeffs ./ sum(coeffs)
    conversions = sum(y) .* attr_weights

    Touchpoint = [k for k in keys(state_mapping_dict) if k ∉ ["(conv)","(start)","(drop)"]]
    tid = [state_mapping_dict[k] for k in keys(state_mapping_dict) if k ∉ ["(conv)","(start)","(drop)"]]

    conversions_df= DataFrame(
        tid = tid, 
        Touchpoint = Touchpoint,
        Conversions = conversions, 
        Model = "LogisticReg")

    if include_heuristics
        conversion_path_df = aggregate_path_data(path_df)
        paths_vec = conversion_path_df.path
        conv_counts_vec = conversion_path_df.total_conversions
        heuristics_df = heuristics(paths_vec, conv_counts_vec, state_mapping_dict)
        conversions_df = vcat(conversions_df, heuristics_df)
    end

    return conversions_df
end