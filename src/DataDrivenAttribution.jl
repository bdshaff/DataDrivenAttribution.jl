module DataDrivenAttribution

export dda_model, dda_touchpoints, dda_mapping, dda_summary, dda_frequency_distribution, dda_markov_model, dda_shapley_model
export aggregate_path_data

using DataFramesMeta
using SplitApplyCombine
using NamedArrays
using Combinatorics
using FreqTables
using LinearAlgebra
using LsqFit
using ProgressBars
using Statistics

dda_model = function(path_df; 
    model = "markov", 
    markov_order = [1],
    include_heuristics = true,
    include_response = false)

    if include_response
        include_summary = true
    end

    if model == "markov"
        conversion_path_df = aggregate_path_data(path_df)
        state_mapping_dict = dda_mapping(path_df)
        conversions_df = dda_markov_model(conversion_path_df, markov_order, state_mapping_dict, include_heuristics)
    end

    if model == "shapley"
        conversion_path_df = aggregate_path_data(path_df, false)
        state_mapping_dict = dda_mapping(path_df)
        conversions_df = dda_shapley_model(conversion_path_df, state_mapping_dict, include_heuristics)
    end

    results_df = @chain conversions_df begin
        unstack(:Model, :Conversions)
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
