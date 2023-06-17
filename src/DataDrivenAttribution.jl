module DataDrivenAttribution

export dda_model, dda_touchpoints, dda_mapping, dda_summary, dda_frequency_distribution
export dda_markov_model, dda_shapley_model, dda_logistic_model, dda_response
export aggregate_path_data, flatten_path_data, heuristics
export plot_conversion_volume, plot_rcr

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
using PlotlyJS


abstract type AttributionModel end

struct MarkovAttributionModel <: AttributionModel
    method::String
    paths::DataFrame
    result::DataFrame
    touchpoints::Dict
    momarkov_orderdel::Array
    transition_matrices::Array
end

struct ShapleyAttributionModel <: AttributionModel
    method::String
    paths::DataFrame
    result::DataFrame
    touchpoints::Dict
    coalitions::Vector
    shapley_df::DataFrame
    values::Dict
end

struct LogisticAttributionModel <: AttributionModel
    method::String
    paths::DataFrame
    result::DataFrame
    touchpoints::Dict
    glm_fit
    attr_weights
end

dda_model = function(path_df::DataFrame; 
    model::String = "markov", 
    markov_order::Array = [1],
    include_heuristics::Bool = true)

    #check format of the DF
    @assert "path" in names(path_df) "Path Data must contain a column names 'path'"
    @assert "conv" in names(path_df) "Path Data must contain a column names 'conv'"
    @assert typeof(path_df.path) == Vector{Vector{String}} "column 'path' must of of type Vector{Vector{String}}"
    @assert typeof(path_df.conv) == Vector{String} "column 'conv' must of of type Vector{String}"
    @assert length(unique(path_df.conv)) == 2 "Check contents of column 'conv'. Must contain both and only '1' and '-1'"
    @assert  "1" in unique(path_df.conv) "Check contents of column 'conv'. Must contain both and only '1' and '-1'"
    @assert  "-1" in unique(path_df.conv) "Check contents of column 'conv'. Must contain both and only '1' and '-1'"
    #check for valid inputs
    @assert typeof(model) == String
    @assert model in ["markov","shapley","logisticreg"] "Check parameter 'model'. Must be one of ('markov','shapley','logisticreg'])"
    @assert typeof(markov_order) == Vector{Int}
    @assert length(markov_order) <= 5 "Currently allowing only up to 5 markov models at a time"
    @assert maximum(markov_order) <= 6 "Currently allowing only markov models of order 6 or lower"

    if model == "markov"
        conversion_path_df = aggregate_path_data(path_df)
        attr_model = dda_markov_model(conversion_path_df, markov_order, include_heuristics = include_heuristics)
    end

    if model == "shapley"
        conversion_path_df = aggregate_path_data(path_df, false)
        attr_model = dda_shapley_model(conversion_path_df, include_heuristics = include_heuristics)
    end

    if model == "logisticreg"
        attr_model = dda_logistic_model(path_df, include_heuristics = include_heuristics)
    end

    #results_df = @chain conversions_df begin unstack(:Model, :Conversions) end
    ##res_dict = Dict(:results_df => results_df, :conversions_df => conversions_df)

    return attr_model

end

include("logisticreg.jl")
include("markov.jl")
include("shapley.jl")
include("utils.jl")
include("mto.jl")
include("visualization.jl")

end
