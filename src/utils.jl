

"""
dda_touchpoints(path_df)
"""
dda_touchpoints = function(path_df::DataFrame)
  if path_df.path isa Vector{String}
    unique_sates_vec = string.(unique(SplitApplyCombine.flatten(split.(path_df.path,">"))))
  elseif path_df.path isa Vector{Vector{String}}
    unique_sates_vec = unique(SplitApplyCombine.flatten(path_df.path))
  end
  unique_sates_vec
end

"""
dda_mapping(path_df)
"""
dda_mapping = function(path_df::DataFrame)
  unique_sates_vec = dda_touchpoints(path_df)
  state_mapping_dict = state_mapping(unique_sates_vec)
  state_mapping_dict
end

"""
dda_summary(path_df)
"""
dda_summary = function(path_df::DataFrame)
  conversion_path_df = aggregate_path_data(path_df)
  paths_vec = conversion_path_df.path
  conv_counts_vec = conversion_path_df.total_conversions
  drop_counts_vec = conversion_path_df.total_null
  state_mapping_dict = dda_mapping(path_df)

  description_df = describe_path_data(paths_vec, conv_counts_vec, drop_counts_vec, state_mapping_dict)
  description_df[:Summary]
end

"""
dda_frequency_distribution(path_df)
"""
dda_frequency_distribution = function(path_df::DataFrame)
  conversion_path_df = aggregate_path_data(path_df)
  paths_vec = conversion_path_df.path
  conv_counts_vec = conversion_path_df.total_conversions
  drop_counts_vec = conversion_path_df.total_null
  state_mapping_dict = dda_mapping(path_df)

  description_df = describe_path_data(paths_vec, conv_counts_vec, drop_counts_vec, state_mapping_dict)
  description_df[:FrequencyDistributions]
end

"""
state_mapping(unique_sates_vec)
"""
state_mapping = function(unique_sates_vec)
    start_conv_states_map = Dict("(start)" => "0", "(conv)" => "1", "(drop)" => "-1")
    transient_states =  unique_sates_vec
    transient_states_map = Dict([(transient_states[i], string(i+1)) for i in eachindex(transient_states)])
    state_map = merge(start_conv_states_map, transient_states_map)

    return state_map
end


"""
apply_mapping(paths, state_mapping_dict)
"""
apply_mapping = function(path, StateMapping::Dict{String, String})
    path_array = split(path, ">")
    for i in eachindex(StateMapping)
        replace!(path_array, i => StateMapping[i])
    end
    return path_array
end

"""
describe_path_data(paths, conv_counts, drop_counts, StateMapping)
"""
describe_path_data = function(paths, conv_counts, drop_counts, StateMapping::Dict{String, String})
    total_counts = conv_counts .+ drop_counts
    total_reach = sum(total_counts)
    path_lengths = count.(">", paths) .+ 1
    total_exposurs = sum(path_lengths .* (total_counts))
    total_avg_freq = total_exposurs/total_reach
    
    
    Touchpoints = String.(keys(StateMapping))
    tids = String.(values(StateMapping))
  
    tids = [t for t in tids if !(t in ["0","1","-1"])]
    Touchpoints = [t for t in Touchpoints if !(t in ["(start)","(conv)","(drop)"])]
  
    rows = []
    freq_dists = []
    
    for i in eachindex(tids)
  
      tid = tids[i]
      Touchpoint = Touchpoints[i]
  
      v = [count(Touchpoint, p) for p in paths]
      exposures = sum(v .* total_counts) #impressions
      pct_exposures = 100 * exposures/total_exposurs #percent of total exposures
      reach = sum((v .> 0) .* total_counts) #reach
      pct_reach = 100 * reach / total_exposurs #percent of total reach
      avg_freq = exposures/reach
  
  
      row = DataFrame(
        :tid => tid,
        :Touchpoint => Touchpoint,
        :exposures => exposures,
        :pct_exposures => pct_exposures,
        :reach => reach,
        :pct_reach => pct_reach,
        :avg_freq => avg_freq,
      )
  
      push!(rows, row)
  
      freq_tbl = freqtable(v[v .> 0])
      freq_dist = DataFrame(tid = tid, Touchpoint = Touchpoint, Frequency = names(freq_tbl,1), Count = freq_tbl)
  
      push!(freq_dists, freq_dist)
  
    end
    
    summaryDF = reduce(vcat, rows)
    freqDF = reduce(vcat, freq_dists)
  
    summaryDF.total_reach .= total_reach
    summaryDF.total_exposurs .= total_exposurs
    summaryDF.total_avg_freq .= total_avg_freq
  
    total_freq_tbl = freqtable(path_lengths)
    total_freq_dist = DataFrame(tid = "ttl", Touchpoint = "Total", Frequency = names(total_freq_tbl,1), Count = total_freq_tbl)
  
    freqDF = vcat(freqDF, total_freq_dist)
  
    return Dict(:Summary => summaryDF, :FrequencyDistributions => freqDF)
end


"""
heuristics(paths, conv_counts, StateMapping)
"""
heuristics = function(paths::Vector{String}, conv_counts::Vector{Int}, StateMapping::Dict{String, String})
    lookup_df = DataFrame(:Touchpoint => String.(keys(StateMapping)), :tid => String.(values(StateMapping)))
    split_paths = [split(p, ">") for p in paths][conv_counts .> 0]
  
    lts = [[String(z[1][end]) for x in 1:z[2]] for z in zip(split_paths, conv_counts[conv_counts .> 0])]
    fts = [[String(z[1][1]) for x in 1:z[2]] for z in zip(split_paths, conv_counts[conv_counts .> 0])]
    last_touch_freq = freqtable(reduce(vcat, lts))
    first_touch_freq = freqtable(reduce(vcat, fts))
  
    LastTouchDF = DataFrame(:Touchpoint => names(last_touch_freq,1), 
                            :Conversions => Vector(last_touch_freq), 
                            :Model => "LastTouch")
    FirstTouchDF = DataFrame(:Touchpoint => names(first_touch_freq,1), 
                            :Conversions => Vector(first_touch_freq),
                            :Model => "FirstTouch")
  
    leftjoin!(LastTouchDF, lookup_df, on = :Touchpoint)
    leftjoin!(FirstTouchDF, lookup_df, on = :Touchpoint)
    DF = reduce(vcat, [LastTouchDF, FirstTouchDF])
    return DF
end

"""
aggregate_path_data(path_df, join_path = true)
"""
aggregate_path_data = function(path_df::DataFrame, join_path = true)
    if join_path
      conversion_path_df = @chain path_df begin
        @rtransform :path = join(:path, ">")
        @rtransform :non_conv = ifelse(:conv == "-1", 1, 0)
        @rtransform :conv = ifelse(:conv == "-1", 0, 1)
        groupby(:path)
        @combine begin
          :total_conversions = sum(:conv)
          :total_null = sum(:non_conv)
        end
        @orderby(-:total_conversions)
      end
    else
      conversion_path_df = @chain path_df begin
        @rtransform :non_conv = ifelse(:conv == "-1", 1, 0)
        @rtransform :conv = ifelse(:conv == "-1", 0, 1)
        groupby(:path)
        @combine begin
          :total_conversions = sum(:conv)
          :total_null = sum(:non_conv)
        end
        @orderby(-:total_conversions)
      end
    end
  
    return conversion_path_df
end
 
"""
flatten_path_data(path_df)
"""
flatten_path_data = function(path_df::DataFrame)
      df = DataFrame(path = push!.(path_df.path, path_df.conv), id = path_df.id)
      df_flat = DataFrames.flatten(df, :path)
      df_flat.Tactic = df_flat.path
      df_flat.Tactic[df_flat.path .== "-1"] .= "(drop)"
      df_flat.Tactic[df_flat.path .== "1"] .= "(conv)"
      df_flat = df_flat[:, [:Tactic, :id]]
  
      return df_flat
end