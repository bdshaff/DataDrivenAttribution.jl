plot_conversion_volume = function(conv_df)
  sort!(conv_df, [:Conversions], rev=true)
  models = unique(conv_df.Model)
  conv_dfs = [conv_df[conv_df.Model .== g,:] for g in models]
  touchpoints = unique(conv_df.Touchpoint)

  layout = Layout(
      barmode = "group", 
      xaxis_tickangle = -65,
      #paper_bgcolor = "rgba(0,0,0,0)",
      plot_bgcolor = "rgba(0,0,0,0)",
      title = "Conversion Volume Attributed",
      yaxis_title="Conversions Attributed",
      )

  plot([
    bar(x = conv_dfs[i].Touchpoint, y = conv_dfs[i].Conversions, text = conv_dfs[i].Conversions,
      name = unique(conv_dfs[i].Model)[1], 
      marker_color = unique(conv_dfs[i].Model)[1],
      texttemplate = "%{text:.2s}", textposition = "outside"
    ) for i in eachindex(conv_dfs)], layout
  )
end


plot_rcr = function(res_df, model_a, model_b)
    res_df.rcr = (res_df[:,model_a] ./ res_df[:,model_b]) .-1
    sort!(res_df, [:rcr], rev=true)

    layout = Layout(
        barmode = "group", 
        xaxis_tickangle = -65,
        #paper_bgcolor = "rgba(0,0,0,0)",
        plot_bgcolor = "rgba(0,0,0,0)",
        title = "Contrast: ".*model_a.*" vs. ".*model_b,
        yaxis_title="Relative Conversion Rate",
    )

    plot([
        bar(x = res_df.Touchpoint, y = res_df.rcr, 
            text = res_df.rcr, marker_color = res_df.rcr,
            texttemplate = "%{text:.3}", textposition = "outside"
        )], layout
    )
end