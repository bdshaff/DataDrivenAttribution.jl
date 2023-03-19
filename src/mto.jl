
"""
reach_curve(x, p0)
"""
function reach_curve(x, p0)
    a = 0
    k, c, q, b, ν = p0
    y = (a + (k - a) ) ./ ( ( c .+ q .* exp.( -b .* x ) ) .^ ( 1/ν) )
    return y
end

"""
fit_response_curves(ResponseTable, ConversionTable, ResutlTable)
"""
fit_response_curves = function(ResponseTable, ConversionTable, ResutlTable)
    tactics = unique(ConversionTable.Touchpoint)
    models = unique(ConversionTable.Model)

    p0 = Float64.([1, 1, 1, 1, 1])
    lb = [1.0, -Inf, -Inf, 0.0, -Inf]
    ub = [Inf, Inf, Inf, Inf, Inf]

    resp_curve_params = []
    for tactic in tactics
        for model in models
            println(tactic * " " * model)
            x = ResponseTable[ResponseTable.Tactic .== tactic, :ExposurePercent]
            y = ResponseTable[ResponseTable.Tactic .== tactic, :ResponsePercent]
            xs = ResutlTable[ResutlTable.Touchpoint .== tactic, :exposures][1]
            ys = ResutlTable[ResutlTable.Touchpoint .== tactic, model][1]
            
            fit = LsqFit.curve_fit(reach_curve, x, y, p0, lower = lb, upper = ub)
            res = (tactic, model, fit.param, xs, ys)
            push!(resp_curve_params, res)
        end
    end
    
    ResponseCurves = DataFrame(resp_curve_params)
    rename!(ResponseCurves, [:Tactic, :Model, :ReachCurveParam, :xs, :ys])
    return ResponseCurves
end

using DataFramesMeta
"""
generate_reach_response(PathDataStream, ConversionTable)
"""
generate_reach_response = function(PathDataStream, ConversionTable)

    tactics = [t for t in unique(PathDataStream.Tactic) if !(t in ["(drop)","(conv)"])]
    rng = 0:0.1:1
    resp = []
    for t in tactics
        df = PathDataStream[PathDataStream.Tactic .== t,:]
        r = [get_reach(df, p) for p in rng]
        push!(resp, r)
    end

    exp_df = @chain PathDataStream begin
        groupby(:Tactic)
        combine(nrow => :exposures)
        @rtransform :ExposurePercent = rng
        @rtransform :Exposure = :exposures .* rng
        @rsubset(!(:Tactic in ["(drop)","(conv)"])) 
        @select :Tactic :Exposure :ExposurePercent 
    end
        
    resp_df = DataFrame( 
        Tactic = tactics,
        Response = resp,
        ResponsePercent = resp ./ maximum.(resp)
    ) 

    leftjoin!(resp_df, exp_df, on = :Tactic)

    ResponseTable = DataFrames.flatten(resp_df, [:Response, :ResponsePercent, :ExposurePercent, :Exposure])

    DF = leftjoin(ConversionTable, ResponseTable[:,[:Tactic, :ResponsePercent]], on = [:Touchpoint => :Tactic])
    DF.ModelResponse = DF.Conversions .* DF.ResponsePercent
    DFF = DF[:, [:Touchpoint, :ResponsePercent, :Model, :ModelResponse]]
    DFFF = unstack(DFF, :Model, :ModelResponse)
    leftjoin!(ResponseTable, DFFF, on = [:Tactic => :Touchpoint, :ResponsePercent])

    return ResponseTable

end

"""
get_reach(df, p)
"""
get_reach = function(df, p)
    sample_rows = rand(1:nrow(df), Int(round((p * nrow(df)))) )
    sample = df[sample_rows,:]
    r = length(unique(sample.id))
    
    return r
end