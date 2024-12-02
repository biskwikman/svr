using DataFrames
using CSV
using Printf
using Statistics
using CairoMakie
using SingularSpectrumAnalysis

tower_key = "RUFyo"
tower_id = 10

ec_df = CSV.read("asia_flux_061.csv", DataFrame)

site_years = unique(select(ec_df, :site_code, :id, [:syear, :eyear] => ((s,e) -> e - s) => :nyears))
sort!(site_years, :nyears)

tse = subset(ec_df, :site_code => x -> x .== "RUFyo")

tower_gpp_df = select(
    filter(
        row -> (row.site_code == tower_key && row.year in row.syear:row.eyear), ec_df
        ),
        [:year, :doy] => ByRow((y,d) -> @sprintf("%s_%03i_%s", y, d, tower_id)) => :Key,
        :gpp => :GPP_Obs, :doy, :year
    )

# Replace missing with seasonal average
# tower_gpp_df.GPP_Obs = replace(tower_gpp_df.GPP_Obs, -9999.0 => missing)
# mean_361 = mean(skipmissing(subset(tower_gpp_df, :doy => x -> x .== 361)[:, :GPP_Obs]))
# tower_gpp_df.GPP_Obs = replace(tower_gpp_df.GPP_Obs, missing => mean_361)
yt, ys = analyze(tower_gpp_df[!,"GPP_Obs"], 46, robust=true)
tower_gpp_df[!, "GPP_Obs_Trend"] = yt

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
    tower_gpp_df[!,"GPP_Output_$c"] = replace(tower_gpp_df[!,"GPP_Output_$c"], missing=>-9999.0)
    sort!(tower_gpp_df)

    yt, ys = analyze(tower_gpp_df[!,"GPP_Output_$c"], 46, robust=true)
    tower_gpp_df[!, "GPP_Output_$(c)_Trend"] = yt
end
n_days = 644
# convert(Vector{Float64}, tower_gpp_df[1:n_days, :GPP_Output_c05])
# println(analyze(convert(Vector{Float64}, tower_gpp_df[1:n_days, :GPP_Output_c05]), 20))
# println(count(ismissing, tower_gpp_df[1:n_days, :GPP_Obs]))
# gpp_obs_fill = subset(tower_gpp_df, :DOY => x -> x .== 361)
# test = transform(tower_gpp_df, :GPP_Obs => ByRow(x -> ismissing(x) ? 1 : 2))

begin
    # n_days = 644

    f = Figure(size=(1000, 600))
        
    ax1 = Axis(
            f[1,1]; 
            xticks=1:46:645, 
            xtickformat=(values) -> ["$(i+1999)" for (i,value) in enumerate(values)],
        )

    lines!(ax1, 
        1:nrow(tower_gpp_df),
        tower_gpp_df.GPP_Obs_Trend;
        linewidth=3,
        color=:gray,
        linestyle=:dot,
        label="EC obs"
    )

    gpp_obs = replace(tower_gpp_df.GPP_Obs, -9999.0 => missing)
    println(tower_gpp_df)
    lines!(ax1, 
        1:nrow(tower_gpp_df),
        gpp_obs,
        linewidth=3,
        color=:gray,
        linestyle=:dot,
        label="EC obs"
    )

    lines!(ax1, 1:nrow(tower_gpp_df), tower_gpp_df.GPP_Output_c05_Trend,alpha=0.7,linewidth=2,label="C05")
    lines!(ax1, 1:nrow(tower_gpp_df), tower_gpp_df.GPP_Output_c06_Trend,alpha=0.7,linewidth=2,label="C06")
    lines!(ax1, 1:nrow(tower_gpp_df), tower_gpp_df.GPP_Output_c61_Trend,alpha=0.7,linewidth=2,label="C61")
    axislegend(ax1,position = :lt)

    println("done")
    # println(cor(collect(skipmissing(tower_gpp_df[:, :GPP_Obs])), collect(skipmissing(tower_gpp_df[:, :GPP_Output_c05]))))
    # println(cor(collect(skipmissing(tower_gpp_df[:, :GPP_Obs])), collect(skipmissing(tower_gpp_df[:, :GPP_Output_c06]))))
    # println(cor(collect(skipmissing(tower_gpp_df[:, :GPP_Obs])), collect(skipmissing(tower_gpp_df[:, :GPP_Output_c61]))))
    # linkyaxes!(ax1, ax2)
    f
    # save("svr_single_site.png", f)


end