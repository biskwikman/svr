using CSV
using DataFrames
using DataFramesMeta
using GLMakie
using GLM
using Printf
using StatsBase


veg_df = DataFrame(CSV.File("./veg_key.csv"))
igbp_df = DataFrame(CSV.File("./igbp.csv"))
rename!(veg_df, [:Site_Code, :Site_ID, :Veg_Type_Code])
forest_veg_types = [1:5]
forest_sites_df = filter(:Veg_Type_Code => x -> x in [1, 2, 3, 4, 5], veg_df)
forest_ids = forest_sites_df[!, 2]
versions = [:c05, :c06, :c61]
ensembles = 201:210;

# Create input df
input_df = DataFrame()
for v in versions
    version_df = DataFrame(CSV.File(@sprintf("./prep_input_%s/svr.test.ALL.GPP.201.txt", String(v)), header=false))
    select!(version_df, Between("Column1", "Column5"))
    insertcols!(version_df, 1, :Version => v)
    append!(input_df, version_df)
end
rename!(input_df, Dict(:Column1 => :Year, :Column2 => :DOY, :Column3 => :Site_ID, :Column4 => :Crossval_ID, :Column5 => :Input_GPP))
input_df[!,:Key] = string.(input_df[:,:Year], "_", input_df[:, :DOY], "_", input_df[:,:Site_ID])
input_df = innerjoin(input_df, veg_df, on=:Site_ID)
# input_df
# println(mean(filter(:Version => isequal(:c61), input_df)[:, :Input_GPP]))
# println(mean(filter(:Version => isequal(:c05), input_df)[:, :Input_GPP]))

# Create output df
output_df = DataFrame()
for v in versions
    for ens in ensembles
        output_file = @sprintf("./CROSSVAL_%s/output_lvmar/CV_%i_ALL_GPP.csv", v, ens)
        version_df = DataFrame(CSV.File(output_file, header=false))
        select!(version_df, Between("Column1", "Column6"))
        insertcols!(version_df, 1, :Version => v)
        insertcols!(version_df, 2, :Ensemble => ens)
        append!(output_df, version_df, cols=:union)
    end
end
rename!(output_df, Dict(:Column1=>:GPP, :Column3=>:Year, :Column4=>:DOY, :Column5=>:Site_ID, :Column6=>:Crossval_ID))
output_df[!, :Key] = string.(output_df[:, :Year], "_", output_df[:, :DOY], "_", output_df[:, :Site_ID])
# output_df
# println(mean(filter(:Version => isequal(:c61), output_df)[:, :GPP]))
# println(mean(filter(:Version => isequal(:c06), output_df)[:, :GPP]))

# Create master df
mdf = innerjoin(select(output_df, :Ensemble=> (x -> string.(x)) => :Ensemble, :GPP, :Key, :Version), input_df, on = [:Key, :Version])
means = @chain mdf begin
    groupby(Cols("Version", "Key"))
    combine(:GPP => mean, :Input_GPP => unique, :Veg_Type_Code => unique, :Year => unique, :DOY => unique, :Site_ID => unique, :Crossval_ID => unique, :Site_Code => unique, renamecols=false)
    insertcols!(1, :Ensemble => "Ensemble Mean")
end
append!(mdf, means)
transform!(mdf, :Veg_Type_Code => (x -> x .∈ [1:5]) => :Forest)
mdf
# println(mean(filter(:Version => isequal(:c61), mdf)[:, :Input_GPP]))
# println(mean(filter(:Version => isequal(:c06), mdf)[:, :Input_GPP]))

# Create statistics df
stats_df = DataFrame()

stats_df = @chain mdf begin
    groupby(Cols(:Version, :Ensemble))
    combine(
        [:Input_GPP, :GPP] => ((x, Y) -> cor(x, Y)^2) => :R2,
        [:Input_GPP, :GPP] => ((x, Y) -> rmsd(x, Y)) => :RMSD,
    )
    select(:, :Ensemble => (x -> string.(x)) => :Ensemble)
    groupby(:Version)
    # @subset(:R2 .== maximum(:R2))
    # sort!(:Version)
end

veg_type_stats_df = @chain mdf begin
    groupby(Cols(:Version, :Ensemble, :Veg_Type_Code))
    combine(
        [:Input_GPP, :GPP] => ((x, Y) -> cor(x, Y)^2) => :R2,
        [:Input_GPP, :GPP] => ((x, Y) -> rmsd(x, Y)) => :RMSD,
    )
    leftjoin!(igbp_df, on = :Veg_Type_Code)
    groupby(Cols(:Version, :Veg_Type))
    @rsubset(:Ensemble ∈ ["Ensemble Mean", "209"])
    # sort([:Version, order(:R2, rev=true)])
end
veg_type_stats_df = veg_type_stats_df[
    veg_type_stats_df.Ensemble .== "Ensemble Mean" .&& 
    veg_type_stats_df.Version .== Symbol("c05") .||
    veg_type_stats_df.Ensemble .== "209" .&& 
    veg_type_stats_df.Version .== Symbol("c06") .|| 
    veg_type_stats_df.Ensemble .== "Ensemble Mean" .&& 
    veg_type_stats_df.Version .== Symbol("c61"),
    :]
sort!(veg_type_stats_df, [:Version, order(:R2, rev=true)])

forest_stats_df = @chain mdf begin
    groupby(Cols(:Version, :Ensemble, :Forest))
    combine(
        [:Input_GPP, :GPP] => ((x, Y) -> cor(x, Y)^2) => :R2,
        [:Input_GPP, :GPP] => ((x, Y) -> rmsd(x, Y)) => :RMSD,
    )
    groupby(Cols(:Version, :Forest))
    @subset(:R2 .== maximum(:R2))
    sort(Cols(:Forest, :Version))
end

print(stats_df)

# Create linear models

c05_lm_df = @subset(mdf, :Version .== Symbol("c05"), :Ensemble .== "Ensemble Mean")
c06_lm_df = @subset(mdf, :Version .== Symbol("c06"), :Ensemble .== "Ensemble Mean")
c61_lm_df = @subset(mdf, :Version .== Symbol("c61"), :Ensemble .== "Ensemble Mean")
select!(c05_lm_df, :Input_GPP => :x, :GPP => :Y)
select!(c06_lm_df, :Input_GPP => :x, :GPP => :Y)
select!(c61_lm_df, :Input_GPP => :x, :GPP => :Y)
c05_ols = lm(@formula(Y ~ x), c05_lm_df)
c06_ols = lm(@formula(Y ~ x), c06_lm_df)
c61_ols = lm(@formula(Y ~ x), c61_lm_df)
olss = (c05 = c05_ols, c06 = c06_ols, c61 = c61_ols)

# ols = lm(@formula(Y ~ x), lm_df)

# forest_df = DataFrame(x = y_i_forest, Y = y_o_forest)
# ols_forest = lm(@formula(Y ~ x), forest_df)

# nonforest_df = DataFrame(x = y_i_nonforest, Y = y_o_nonforest)
# ols_nonforest = lm(@formula(Y ~ x), nonforest_df)

axislabelsize = 45
ticklabelsize = 50
f = Figure(size = (2000, 700))
# titles = [:V05, :V06, :V61]
titles = ["C5", "C6", "C6.1"]
for (i, df) in enumerate([c05_lm_df, c06_lm_df, c61_lm_df])
    if i == 1
        yticklabelsvisible=true
        ylabelvisible=true
    else 
        yticklabelsvisible=false
        ylabelvisible=false
    end
    
    ax = Axis(f[1, i], title=String(titles[i]),
        titlesize=45,
        # xlabel=rich("Obs GPP (gC m",superscript("2")," day",superscript("-1"),")"),
        xlabel=L"Obs\; GPP\; (gC m^{2}\; day^{-1})",
        # ylabel=rich("SVR GPP (gC m",superscript("2")," day",superscript("-1"),")"),
        ylabel=L"SVR\; GPP\; (gC m^{2}\; day^{-1})",
        ylabelvisible=ylabelvisible,
        limits=(0, 18, 0, 18),
        aspect=DataAspect(),
        ylabelsize=axislabelsize,
        xlabelsize=axislabelsize,
        xticklabelsize=ticklabelsize,
        yticklabelsize=ticklabelsize,
        yticklabelsvisible=yticklabelsvisible,
    )

    scatter!(ax, df.x, df.Y; markersize=6, alpha=0.3)
    lines!(ax, df.x, predict(olss[i]), color="black", linewidth=5)

    texts = [
            # rich("y = $(round(coef(olss[i])[2], digits = 2))x + $(round(coef(olss[i])[1], digits = 2))"),
            rich("r", superscript("2"), " = $(round(r2(olss[i]), digits = 2))"),
            rich("RMSE = $(round(rmsd(df.Y, df.x), digits=2))"),
            # rich("n = $(length(df.Y))"), 
    ]
    
    for (i, text) in enumerate(texts)
        text!(
            ax, 0, 1, 
            text=text,
            align=(:left, :top),
            offset = (4, (i-1)*-50),
            space=:relative,
            fontsize=45,
        )
    end
end
f