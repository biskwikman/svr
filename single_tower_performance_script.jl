using DataFrames
using CSV
using Printf
using Statistics
using CairoMakie

tower_key = "HFK"
tower_id = 38

ec_df = CSV.read("asia_flux_061.csv", DataFrame);

tower_gpp_df = select(
    filter(
        row -> (row.site_code == tower_key && row.year in row.syear:row.eyear), ec_df
        ),
        [:year, :doy] => ByRow((y,d) -> @sprintf("%s_%03i_%s", y, d, tower_id)) => :Key,
        # [:year, :doy] => ByRow((y,d) -> "$(y)_$(d)_$(tower_id)") => :Key,
        :gpp => :GPP_Obs
    )

tower_gpp_df.GPP_Obs = replace(tower_gpp_df.GPP_Obs, -9999.0 => missing)

ensembles = 201:210

for c in ["c05","c06","c61"]
    output_df = DataFrame()
    for ens in ensembles
        output_file = @sprintf("./CROSSVAL_%s/output_lvmar/CV_%i_ALL_GPP.csv", c, ens)
        version_df = DataFrame(CSV.File(output_file, header=false))
        select!(version_df, Between("Column1", "Column6"))
        insertcols!(version_df, 1, :Version => Symbol(c))
        insertcols!(version_df, 2, :Ensemble => ens)
        append!(output_df, version_df, cols=:union)
    end

    rename!(output_df, Dict(:Column1=>:GPP, :Column3=>:Year, :Column4=>:DOY, :Column5=>:Site_ID, :Column6=>:Crossval_ID))

    output_df[!, :Key] = string.(output_df[:, :Year], "_", string.(output_df[:, :DOY], pad = 3), "_", output_df[:, :Site_ID])

    if c == "c06"
        output_gpp_df = subset!(output_df, :Ensemble => e -> e.==209, :Site_ID => s -> s.== tower_id)
        rename!(output_gpp_df, :GPP=>Symbol("GPP_Output_$c"))
    elseif c ∈ ["c05", "c61"]
        output_gpp_df = combine(groupby(filter(row -> row.Site_ID == tower_id, output_df), :Key), :GPP => mean => Symbol("GPP_Output_$c"))
    end

    global tower_gpp_df = leftjoin(tower_gpp_df, output_gpp_df, on=:Key)
    sort!(tower_gpp_df)

end

# println(tower_gpp_df)

begin 
    n_days_1 = 276
    n_days_total = 598

    f = Figure(size=(1000, 600))
        
    ax1 = Axis(
            f[1,1]; 
            xticks=1:46:46*7, 
            xtickformat=(values) -> ["$(i+2002)" for (i,value) in enumerate(values)],
        )

    ax2 = Axis(
        f[2,1]; 
        xticks=n_days_1+1:46:n_days_total+46, 
        xtickformat=(values) -> ["$(i+2008)" for (i,value) in enumerate(values)],
    )

    lines!(ax1, 
        1:n_days_1,
        tower_gpp_df[1:n_days_1, :GPP_Obs];
        linewidth=3,
        color=:gray,
        linestyle=:dot,
    )

    lines!(ax1, 1:n_days_1, tower_gpp_df[1:n_days_1, :GPP_Output_c05],alpha=0.7,linewidth=2,label="C05")
    lines!(ax1, 1:n_days_1, tower_gpp_df[1:n_days_1, :GPP_Output_c06],alpha=0.7,linewidth=2,label="C06")
    lines!(ax1, 1:n_days_1, tower_gpp_df[1:n_days_1, :GPP_Output_c61],alpha=0.7,linewidth=2,label="C61")
    axislegend(ax1,position = :lt)

    lines!(ax2, 
        n_days_1+1:n_days_total,
        tower_gpp_df[n_days_1+1:end, :GPP_Obs];
        linewidth=3,
        color=:gray,
        linestyle=:dot,
    )

    lines!(ax2, n_days_1+1:n_days_total, tower_gpp_df[n_days_1+1:end, :GPP_Output_c05],alpha=0.7,linewidth=2)
    lines!(ax2, n_days_1+1:n_days_total, tower_gpp_df[n_days_1+1:end, :GPP_Output_c06],alpha=0.7,linewidth=2)
    lines!(ax2, n_days_1+1:n_days_total, tower_gpp_df[n_days_1+1:end, :GPP_Output_c61],alpha=0.7,linewidth=2)

    linkyaxes!(ax1, ax2)
    f
    # save("svr_single_site.png", f)
end

println("done")
println(cor(collect(skipmissing(tower_gpp_df[:, :GPP_Obs])), collect(skipmissing(tower_gpp_df[:, :GPP_Output_c05]))))
println(cor(collect(skipmissing(tower_gpp_df[:, :GPP_Obs])), collect(skipmissing(tower_gpp_df[:, :GPP_Output_c06]))))
println(cor(collect(skipmissing(tower_gpp_df[:, :GPP_Obs])), collect(skipmissing(tower_gpp_df[:, :GPP_Output_c61]))))