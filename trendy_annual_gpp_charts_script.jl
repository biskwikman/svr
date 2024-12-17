using JLD2
using CairoMakie
using Statistics
using StatsBase
using DataFrames
using BenchmarkTools

println("Begin")

models = [
		"cable_pop",
		"classic",
		"clm50",
		"e3sm",
		"edv3",
		"ibis",
		"isba_ctrip",
		"jsbach",
		"jules",
		"lpj_guess",
		"lpjml",
		"lpjwsl",
		"lpx_bern",
		"ocn",
		"orchidee",
		"sdgvm",
		"visit",
	]

areas_file = "./AsiaMIP_qdeg_area.flt"
areas = Array{Float32}(undef, (480, 360))
read!(areas_file, areas)
areas = convert(Array{Union{Missing, Float32}}, areas)
reverse!(areas; dims=2)
replace!(areas, -9999.0 => missing)

regions_file = "./AsiaMIP_qdeg_gosat2.byt"
regions_array = Array{UInt8}(undef, (480, 360))
read!(regions_file, regions_array)
reverse!(regions_array; dims=2)

siberia_idx = findall(x -> x in(range(1,4)), regions_array)
easia_idx = findall(x -> x == 6, regions_array)
sasia_idx = findall(x -> x == 7, regions_array)
seasia_idx = findall(x -> x in(range(8,9)), regions_array)
regions_idx = [siberia_idx, easia_idx, sasia_idx, seasia_idx]

regions = Dict(
    "East Asia" => easia_idx,
    "Southeast Asia" => seasia_idx,
    "South Asia" => sasia_idx,
    "Siberia" => siberia_idx,
)

function apply_weights(yearly_ave_spatial, areas, regions)
    result = areas .* yearly_ave_spatial
    missing_areas = findall(x -> ismissing(x), result)
    areas[missing_areas] .= missing
    
    total_area = sum(skipmissing(areas))
    mean_all = sum(skipmissing(result)) / total_area
    
    se_asia_area = sum(skipmissing(areas[regions["Southeast Asia"]]))
    mean_se_asia = sum(skipmissing(result[regions["Southeast Asia"]])) / se_asia_area
    
    e_asia_area = sum(skipmissing(areas[regions["East Asia"]]))
    mean_e_asia = sum(skipmissing(result[regions["East Asia"]])) / e_asia_area

    siberia_area = sum(skipmissing(areas[regions["Siberia"]]))
    mean_siberia = sum(skipmissing(result[regions["Siberia"]])) / siberia_area

    s_asia_area = sum(skipmissing(areas[regions["South Asia"]]))
    mean_s_asia = sum(skipmissing(result[regions["South Asia"]])) / s_asia_area
    
    return (mean_all, mean_se_asia, mean_e_asia, mean_siberia, mean_s_asia)
end

f = jldopen("./trendy_gpp_annual_spatial_mean.jld2")
models_aves = Dict()
se_asia_aves = Dict()
e_asia_aves = Dict()
siberia_aves = Dict()
s_asia_aves = Dict()
for model in models
    model_ave_all::Vector{Float32} = []
    model_ave_se_asia::Vector{Float32} = []
    model_ave_e_asia::Vector{Float32} = []
    model_ave_siberia::Vector{Float32} = []
    model_ave_s_asia::Vector{Float32} = []
    for year in 1:21
        yearly_ave_spatial = f[model][:,:,year]
        
        yearly_ave_spatial_weighted = apply_weights(yearly_ave_spatial, areas, regions)

        push!(model_ave_all, yearly_ave_spatial_weighted[1])
        push!(model_ave_se_asia, yearly_ave_spatial_weighted[2])
        push!(model_ave_e_asia, yearly_ave_spatial_weighted[3])
        push!(model_ave_siberia, yearly_ave_spatial_weighted[4])
        push!(model_ave_s_asia, yearly_ave_spatial_weighted[5])
        
        models_aves[model] = model_ave_all
        se_asia_aves[model] = model_ave_se_asia
        e_asia_aves[model] = model_ave_e_asia
        siberia_aves[model] = model_ave_siberia
        s_asia_aves[model] = model_ave_s_asia
    end
end

years = 2000:2020

svr_aves_c61::Vector{Float32} = []
svr_aves_c61_se_asia::Vector{Float32} = []
svr_aves_c61_e_asia::Vector{Float32} = []
svr_aves_c61_siberia::Vector{Float32} = []
svr_aves_c61_s_asia::Vector{Float32} = []
for (i, year) in enumerate(years)
    yearly_ave_spatial = Array{Float32}(undef, (480, 360))
    read!("./out_c61/YEAR_cor/GPP.ALL.AVERAGE.$year.flt", yearly_ave_spatial)
    yearly_ave_spatial = convert(Array{Union{Missing, Float32}}, yearly_ave_spatial)
    replace!(yearly_ave_spatial, -9999.0 => missing)
    replace!(yearly_ave_spatial, -999.0 => missing)
    reverse!(yearly_ave_spatial; dims=2)

    yearly_ave = apply_weights(yearly_ave_spatial, areas, regions)

    push!(svr_aves_c61, yearly_ave[1])
    push!(svr_aves_c61_se_asia, yearly_ave[2])
    push!(svr_aves_c61_e_asia, yearly_ave[3])
    push!(svr_aves_c61_siberia, yearly_ave[4])
    push!(svr_aves_c61_s_asia, yearly_ave[5])
end

svr_aves_c06::Vector{Float32} = []
svr_aves_c06_se_asia::Vector{Float32} = []
svr_aves_c06_e_asia::Vector{Float32} = []
svr_aves_c06_siberia::Vector{Float32} = []
svr_aves_c06_s_asia::Vector{Float32} = []
for (i, year) in enumerate(years)
    yearly_ave_spatial = Array{Float32}(undef, (480, 360))
    read!("./out_c06/YEAR_cor/GPP.ALL.AVERAGE.$year.flt", yearly_ave_spatial)
    yearly_ave_spatial = convert(Array{Union{Missing, Float32}}, yearly_ave_spatial)
    replace!(yearly_ave_spatial, -9999.0 => missing)
    reverse!(yearly_ave_spatial; dims=2)

    yearly_ave = apply_weights(yearly_ave_spatial, areas, regions)
    
    push!(svr_aves_c06, yearly_ave[1])
    push!(svr_aves_c06_se_asia, yearly_ave[2])
    push!(svr_aves_c06_e_asia, yearly_ave[3])
    push!(svr_aves_c06_siberia, yearly_ave[4])
    push!(svr_aves_c06_s_asia, yearly_ave[5])
end

svr_aves_c05::Vector{Float32} = []
svr_aves_c05_se_asia::Vector{Float32} = []
svr_aves_c05_e_asia::Vector{Float32} = []
svr_aves_c05_siberia::Vector{Float32} = []
svr_aves_c05_s_asia::Vector{Float32} = []
for (i, year) in enumerate(2000:2015)
    yearly_ave_spatial = Array{Float32}(undef, (480, 360))
    read!("./out_c05/YEAR_cor/GPP.ALL.AVERAGE.$year.flt", yearly_ave_spatial)
    yearly_ave_spatial = convert(Array{Union{Missing, Float32}}, yearly_ave_spatial)
    replace!(yearly_ave_spatial, -999.0 => missing)
    reverse!(yearly_ave_spatial; dims=2)

    yearly_ave = apply_weights(yearly_ave_spatial, areas, regions)
    
    push!(svr_aves_c05, yearly_ave[1])
    push!(svr_aves_c05_se_asia, yearly_ave[2])
    push!(svr_aves_c05_e_asia, yearly_ave[3])
    push!(svr_aves_c05_siberia, yearly_ave[4])
    push!(svr_aves_c05_s_asia, yearly_ave[5])
end

svr_data_asia = Dict(
    "005" => svr_aves_c05,
    "006" => svr_aves_c06,
    "061" => svr_aves_c61,
)
svr_data_e_asia = Dict(
    "005" => svr_aves_c05_e_asia,
    "006" => svr_aves_c06_e_asia,
    "061" => svr_aves_c61_e_asia,
)
svr_data_se_asia = Dict(
    "005" => svr_aves_c05_se_asia,
    "006" => svr_aves_c06_se_asia,
    "061" => svr_aves_c61_se_asia,
)
svr_data_siberia = Dict(
    "005" => svr_aves_c05_siberia,
    "006" => svr_aves_c06_siberia,
    "061" => svr_aves_c61_siberia,
)
svr_data_s_asia = Dict(
    "005" => svr_aves_c05_s_asia,
    "006" => svr_aves_c06_s_asia,
    "061" => svr_aves_c61_s_asia,
)

vers = ["005", "006", "061"]
svr_data_dfs = Dict()
trendy_data_dfs = Dict()
for (region, svr_data, trendy_data) in zip(
    ["Siberia", "South Asia", "Southeast Asia", "East Asia"],
    [svr_data_siberia, svr_data_s_asia, svr_data_se_asia, svr_data_e_asia],
    [siberia_aves, s_asia_aves, se_asia_aves, e_asia_aves],
)
    svr_df = DataFrame("Years"=>2000:2020)
    trendy_df = DataFrame("Years"=>2000:2020)
    
    for ver in vers
        ver_data = convert(Vector{Union{Float32, Missing}}, svr_data[ver])
        while length(ver_data) < 21; push!(ver_data, missing) end
        svr_df[!, ver] = ver_data
    end

    for model in models
        model_data = convert(Vector{Union{Float32, Missing}}, trendy_data[model])
        while length(model_data) < 21; push!(model_data, missing) end
        trendy_df[!, model] = model_data
    end
    
    svr_data_dfs[region] = svr_df
    trendy_data_dfs[region] = trendy_df
end
println(svr_data_dfs)

for region_df in trendy_data_dfs
    select!(region_df[2], Not([:Years]))
    transform!(region_df[2], All() .=> x -> x .- mean(x[1:6]))
    select!(region_df[2], r"function")
    transform!(region_df[2], AsTable(:) => ByRow(std) => :std)
    transform!(region_df[2], AsTable(Not([:std])) => ByRow(mean) => :mean)
    trendy_data_dfs[region_df[1]] = region_df[2]
end

for region_df in svr_data_dfs
    select!(region_df[2], Not([:Years]))
    transform!(region_df[2], All() .=> x -> x .- mean(x[1:6]))
    select!(region_df[2], r"function")
    svr_data_dfs[region_df[1]] = region_df[2]
end

begin
titles = ["Siberia", "South Asia", "Southeast Asia", "East Asia"]
colormap = Makie.wong_colors()
fig = Figure(size = (600,600))

axs = [Axis(
    fig[y,x],
    aspect=1,
    xlabel="Year",ylabel=rich("kgC m", superscript("2"), " year", superscript("-1")),
    xticks=2000:5:2020,
    xminorgridvisible=true,xminorticks=2000:2020,
    xlabelvisible=(y == 1 ? false : true),xticklabelsvisible=(y == 2 ? true : false),
    ylabelvisible=(x == 1 ? true : false),
) for y in 1:2 for x in 1:2]

for (i, region_df) in enumerate(trendy_data_dfs)
    ax_idx = findfirst(==(region_df[1]), titles)
    ax = axs[ax_idx]
    ax.title=region_df[1]
    band!(ax,years,region_df[2][:, :mean] .- region_df[2][:, :std], region_df[2][:, :mean] .+ region_df[2][:, :std], color=:lightgray, label="TRENDY")
end

for region_df in svr_data_dfs
    ax_idx = findfirst(==(region_df[1]), titles)
    ax = axs[ax_idx]
    lines!(ax,years,region_df[2][:, "005_function"], linewidth=3, label="C5")
    lines!(ax,years,region_df[2][:, "006_function"], linewidth=3, label="C6")
    lines!(ax,years,region_df[2][:, "061_function"], linewidth=3, label="C61")
end

linkyaxes!(axs[1],axs[2],axs[3],axs[4])

axislegend(axs[1],position=:lt)

fig
save("/home/dan/Documents/modis_svr_paper/graphics/trendy_charts.png", fig)
end