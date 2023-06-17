
"""
create_count_matrix(UniqueStateValues)
"""
create_count_matrix = function(UniqueStateValues)
    CountMatrix = NamedArray(zeros(Int64, length(UniqueStateValues), length(UniqueStateValues)))
    setdimnames!(CountMatrix, [:trans_from, :trans_to])
    setnames!(CountMatrix, UniqueStateValues, 1)
    setnames!(CountMatrix, UniqueStateValues, 2)

    return CountMatrix
end

"""
transition_matrix(paths, conv_counts, drop_counts, state_mapping_dict, n = 1)
"""
transition_matrix = function(paths, conv_counts, drop_counts, state_mapping_dict, n = 1)
    path_counts = conv_counts .+ drop_counts
    
    #t0 = now()
    StateMapping = state_mapping_dict
    #println("state_mapping: " .* string(now() - t0))
  
    #t0 = now()
    mapped_paths = [apply_mapping(p, StateMapping) for p in paths]
    #println("apply_mapping: " .* string(now() - t0))
  
    #t0 = now()
    if n > 1
      mapped_paths = norder_paths(mapped_paths, n)
      UniqueStateValues = String.(unique(vcat(mapped_paths...)))
      append!(UniqueStateValues, ["0","1","-1"])
      path_lengths = length.(mapped_paths)
    elseif n == 1
      UniqueStateValues = String.(values(StateMapping))
    end
    path_lengths = length.(mapped_paths)
    #println("path_lengths: " .* string(now() - t0))
  
    #set up the count matrix
    #t0 = now()
    CountMatrix = create_count_matrix(UniqueStateValues)
    #println("create_count_matrix: " .* string(now() - t0))
    
  
    #updating the count matrix
    ####################################
    ####################################
  
    #t0 = now()
    #Paths of length >1 
    valid_paths = mapped_paths[path_lengths .> 1]
    valid_path_counts = path_counts[path_lengths .> 1]
    valid_inputs = [z for z in zip(valid_paths, valid_path_counts)]
    #println("valid_inputs: " .* string(now() - t0))
  
    #t0 = now()
    for i in eachindex(valid_inputs)
      update_count_matrix!(CountMatrix, valid_inputs[i])
    end
    #println("update_count_matrix!: " .* string(now() - t0))
  
    #t0 = now()
    first_states = [m[1] for m in mapped_paths[path_lengths .> 0]]
    last_states = [m[end] for m in mapped_paths[path_lengths .> 0]]
    start_counts = freqtable(first_states, weights = path_counts[path_lengths .> 0])
    conv_col = freqtable(last_states, weights = conv_counts[path_lengths .> 0])
    drop_col = freqtable(last_states, weights = drop_counts[path_lengths .> 0])
    #println("freqtable: " .* string(now() - t0))
  
    #t0 = now()
    CountMatrix["0", String.(names(start_counts, 1))] = start_counts
    CountMatrix[String.(names(conv_col, 1)), "1"] = conv_col
    CountMatrix[String.(names(drop_col, 1)), "-1"] = drop_col
    #println("update with freqtable: " .* string(now() - t0))
  
    #t0 = now()
    CountMatrix[diagind(CountMatrix)] .= 0.0
    #println("diag: " .* string(now() - t0))
  
    row_sums = sum(CountMatrix, dims = 2)
    ####################################
    ####################################
  
  
    #Compute Transition Matrix
    ####################################
    ####################################
    #t0 = now()
    TransitionMatrix = CountMatrix ./ row_sums
    TransitionMatrix["-1",:] .= 0.0
    TransitionMatrix["1",:] .= 0.0
    TransitionMatrix["1","1"] = 1.0
    TransitionMatrix["-1","-1"] = 1.0
    #println("TransitionMatrix: " .* string(now() - t0))
  
    TransitionMatrix[isnan.(TransitionMatrix)] .= 0
  
    return TransitionMatrix
  
end

"""
update_count_matrix!(CountMatrix, input)
"""
update_count_matrix! = function(CountMatrix, input)
    path_array = input[1]
    paths_count = input[2]
    for i in 2:lastindex(path_array)
        from = String(path_array[i-1])
        to = String(path_array[i])
        CountMatrix[from,to] += (1 * paths_count)
    end
    nothing
end

"""
norder_path(path, z)
"""
norder_path = function(path, z)
    pll = [path[i[1]:(end-i[2])] for i in z]
    norder_path = []
    for j in eachindex(pll[1])
        np = pll[1][j]
        for i in 2:lastindex(pll)
            np = np * "U" * pll[i][j]
        end
        push!(norder_path, np)
    end
    return norder_path
end

"""
norder_paths(paths, n)
"""
norder_paths = function(paths, n)
    z = zip(collect(1:1:n), collect((n-1):-1:0))
    norder_paths = [norder_path(p, z) for p in paths]
    norder_paths[length.(norder_paths) .> 0]
    return norder_paths
end

"""
removal_effect(TransitionMatrix, State, BaseCVR)
"""
removal_effect = function(TransitionMatrix, State, BaseCVR)

    nms = names(TransitionMatrix,1)
    ix_to = occursin.(Regex("^$(State)U"), nms)
    ix_from = occursin.(Regex("U$(State)\$"), nms)
    ix_between = occursin.(Regex("U$(State)U"), nms)
    ix = (ix_to .+ ix_from .+ ix_between) .== 0

    if sum(ix) == length(nms)
        ix = occursin.(State, nms) .== 0
    end

    RemovalMatrix = TransitionMatrix[ix,ix][Not(["-1","1"]),:]

    row_sums = 1 .- Array(sum(RemovalMatrix, dims = 2))[:]
    RemovalMatrix[:,"-1"] = row_sums
    C = RemovalMatrix[:,["-1","1"]]
    X = RemovalMatrix[:,Not(["-1","1"])]
    Iₙ = I(size(X)[1])
    D₋₁ = inv(Iₙ - X)

    f1 = findall(names(C)[1] .==  "0")[1]
    f2 = findall(names(C)[2] .==  "1")[1]

    RemovalCVR = [D₋₁ * C][1][f1,f2]
    RemovalEffect = 1 - (RemovalCVR/BaseCVR)
    
    return RemovalEffect
end

"""
base_cvr(TransitionMatrix)
"""
base_cvr = function(TransitionMatrix)
    RemovalMatrix = TransitionMatrix[Not(["-1","1"]),:]
        
    row_sums = 1 .- Array(sum(RemovalMatrix, dims = 2))[:]
    RemovalMatrix[:,"-1"] = row_sums
    C = RemovalMatrix[:,["-1","1"]]
    X = RemovalMatrix[:,Not(["-1","1"])]
    Iₙ = I(size(X)[1])
    D₋₁ = inv(Iₙ - X)
  
    f1 = findall(names(C)[1] .==  "0")[1]
    f2 = findall(names(C)[2] .==  "1")[1]
  
    RemovalCVR = [D₋₁ * C][1][f1,f2]
    
    return RemovalCVR
end

"""
compute_markov_df(TransitionMatrix, state_mapping_dict, conv_counts_vec, n)
"""
compute_markov_df = function(TransitionMatrix, state_mapping_dict, conv_counts_vec, n)
    BaseCVR = base_cvr(TransitionMatrix)
    removal_effects_vec = [(s, removal_effect(TransitionMatrix, s, BaseCVR)) for s in String.(values(state_mapping_dict)) if !(s in ["0","-1","1"])]


    markov_df =  DataFrame(removal_effects_vec)
    rename!(markov_df, [:tid,:re])
    markov_df."Conversions" = sum(conv_counts_vec).* markov_df.re/sum(markov_df.re)
    markov_df."Model" .= "Markov"*"_$(n)"
  
    touchpoint_lookup_df = DataFrame(
      :tid => String.(values(state_mapping_dict)),
      :Touchpoint => String.(keys(state_mapping_dict))
    )

    leftjoin!(markov_df, touchpoint_lookup_df, on = :tid)
    DataFrames.sort!(markov_df, [:re], rev = true)

    markov_df = markov_df[:, [:tid, :Touchpoint, :Conversions, :Model]]

    return markov_df
end


dda_markov_model = function(conversion_path_df::DataFrame, markov_order::Array; include_heuristics = true)
    paths_vec = conversion_path_df.path
    conv_counts_vec = conversion_path_df.total_conversions
    drop_counts_vec = conversion_path_df.total_null
    
    state_mapping_dict = dda_mapping(conversion_path_df)

    transition_matrices_vec = 
    [
      transition_matrix(paths_vec, conv_counts_vec, drop_counts_vec, state_mapping_dict, i) 
      for i in markov_order
    ]
  
    markov_df_vec = 
    [
      compute_markov_df(z[1], state_mapping_dict, conv_counts_vec, z[2]) 
      for z in zip(transition_matrices_vec, markov_order)
    ]
  
    conversions_df = reduce(vcat, markov_df_vec)

    if include_heuristics
        heuristics_df = heuristics(paths_vec, conv_counts_vec, state_mapping_dict)
        conversions_df = vcat(conversions_df, heuristics_df)
    end

    #model = Dict("markov_order" => markov_order, "transition_matrices" => transition_matrices_vec)
    res = MarkovAttributionModel("markov", conversion_path_df, conversions_df, state_mapping_dict, markov_order, transition_matrices_vec)
    return res
  end