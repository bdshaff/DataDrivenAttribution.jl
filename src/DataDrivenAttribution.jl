module DataDrivenAttribution

export dda

using DataFramesMeta
using SplitApplyCombine
using NamedArray
using Combinatorics
using FreqTables
using LinearAlgebra
using LsqFit
using ProgressBars
using Statistics

dda = function(path_df; 
    model = "markov", 
    markov_order = [1],
    include_heuristics = true,
    include_summary = true,
    include_response = false)

    if include_response
        include_summary = true
    end

    unique_sates_vec = unique(SplitApplyCombine.flatten(path_df.path))
    state_mapping_dict = state_mapping(unique_sates_vec)

    if model == "markov"
        conversion_path_df = aggregate_path_data(path_df)

        paths_vec = conversion_path_df.path
        conv_counts_vec = conversion_path_df.total_conversions
        drop_counts_vec = conversion_path_df.total_null
        #state_mapping_dict = state_mapping(paths)

        #unique_sates_vec = unique(SplitApplyCombine.flatten(path_df.path))
        #state_mapping_dict = state_mapping(unique_sates_vec)
        transition_matrices_vec = [transition_matrix(paths_vec, conv_counts_vec, drop_counts_vec, state_mapping_dict, i) for i in markov_order]
        markov_df_vec = [compute_markov_df(z[1], state_mapping_dict, conv_counts_vec, z[2]) for z in zip(transition_matrices_vec, markov_order)]

        conversions_df = reduce(vcat, markov_df_vec)

    end

    if model == "shapley"
        conversion_path_df = aggregate_path_data(path_df, false)
        paths_vec = conversion_path_df.path
        conv_counts_vec = conversion_path_df.total_conversions
        drop_counts_vec = conversion_path_df.total_null
        #unique_sates_vec = unique(SplitApplyCombine.flatten(paths_vec))
        #state_mapping_dict = state_mapping(unique_sates_vec)

        coalitions_vec = get_coalitions(unique_sates_vec)
        permutations_vec = get_permutations(unique_sates_vec)
        cr_dict = get_coalition_conversion_rates_dict(coalitions_vec, paths_vec, conv_counts_vec, drop_counts_vec)
        values_dict = get_values_dict(coalitions_vec, cr_dict)
        shapley_df = get_shapley_values(state_mapping_dict, permutations_vec, values_dict)
        conversions_df = get_shapley_conversions(shapley_df, conv_counts_vec)
    end

    if include_heuristics
        paths_vec = aggregate_path_data(path_df).path
        heuristics_df = heuristics(paths_vec, conv_counts_vec, state_mapping_dict)
        conversions_df = vcat(conversions_df, heuristics_df)
    end

    results_df = @chain conversions_df begin
        unstack(:Model, :Conversions)
    end

    if include_summary
        description_df = describe_path_data(paths_vec, conv_counts_vec, drop_counts_vec, state_mapping_dict)
        summary_df = description_df[:Summary]
        #FDF = description_df[:FrequencyDistributions]
        leftjoin!(results_df, summary_df, on = [:tid, :Touchpoint])
    end

    res_dict = Dict(:results_df => results_df, :conversions_df => conversions_df)

    if include_response
        stream_path_df = flatten_path_data(path_df)
        response_df = generate_reach_response(stream_path_df, conversions_df)
        curves_df = fit_response_curves(response_df, conversions_df, results_df)
        push!(res_dict, :response_df => response_df)
        push!(res_dict, :curves_df => curves_df)
    end

    return res_dict

end

include("markov.jl")
include("shapley.jl")
include("utils.jl")
include("mto.jl")

end
