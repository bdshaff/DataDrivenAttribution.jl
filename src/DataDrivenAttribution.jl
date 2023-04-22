module DataDrivenAttribution

export dda_model, dda_touchpoints, dda_mapping, dda_summary, dda_frequency_distribution
export dda_markov_model, dda_shapley_model, dda_logistic_model, dda_response
export aggregate_path_data, flatten_path_data, heuristics

using DataFramesMeta
using SplitApplyCombine
using NamedArrays
using Combinatorics
using FreqTables
using LinearAlgebra
using LsqFit
using ProgressBars
using Statistics
using GLM

dda_model = function(path_df; 
    model = "markov", 
    markov_order = [1],
    include_heuristics = true)

    #check format of the DF
    #check for valid inputs

    if model == "markov"
        conversion_path_df = aggregate_path_data(path_df)
        conversions_df = dda_markov_model(conversion_path_df, markov_order, include_heuristics = include_heuristics)
    end

    if model == "shapley"
        conversion_path_df = aggregate_path_data(path_df, false)
        conversions_df = dda_shapley_model(conversion_path_df, include_heuristics = include_heuristics)
    end

    if model == "logisticreg"
        conversions_df = dda_logistic_model(path_df, include_heuristics = include_heuristics)
    end

    results_df = @chain conversions_df begin
        unstack(:Model, :Conversions)
    end

    res_dict = Dict(:results_df => results_df, :conversions_df => conversions_df)

    return res_dict

end

include("logisticreg.jl")
include("markov.jl")
include("shapley.jl")
include("utils.jl")
include("mto.jl")

end
