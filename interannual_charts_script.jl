using Printf
using Statistics
using CairoMakie
using Makie.Colors
using Dates
using DataFrames
using MLJ
import MLJScikitLearnInterface
using StatsBase
using MannKendall

line_years = 2000:2020
legendlabelsize = 16
legendtitlesize = 16
legendwidth = 3
versionlabelsize = 20
regionnamefontsize = 20
axistitlesize = 16
ticklabelsize = 16
linewidth = 3
reglinewidth = 4
yearformat = xs -> ["'$(SubString(string(x), 3,4))" for x in xs]
xticks = 2000:5:2020
linestyle = Linestyle([0.5, 1.0, 1.8, 3.0])
versions = ["005", "006", "061"]

function get_sample_data()
	sample_filepath = "./out_c05/YEAR_cor/GPP.ALL.AVERAGE.2015.flt"
	prod_sample = Array{Float32}(undef, 480, 360)
	read!(sample_filepath, prod_sample)
	prod_sample = convert(Array{Union{Missing, Float32}}, prod_sample)
	replace!(prod_sample, -999.0 => missing)
	prod_missing_areas = findall(x -> ismissing(x), prod_sample)
	return prod_missing_areas
end

areas_file = "./AsiaMIP_qdeg_area.flt"
mask_file = "./AsiaMIP_qdeg_gosat2.byt"
years = range(2000, 2020)
mod11a2 = ["LST_Day", "LST_Night"]
mod13a2 = ["EVI", "NDVI"]
mod15a2 = ["Fpar", "Lai"]
products = Dict(
    "MOD11A2" => mod11a2,
    "MOD13A2" => mod13a2,
    "MOD15A2H" => mod15a2,
)

region_names = ["East Asia","Southeast Asia","South Asia","Siberia"]

yearly_means = Dict(
    "South Asia" => Dict{String, Float32}(), 
    "Southeast Asia" => Dict{String, Float32}(), 
    "Siberia" => Dict{String, Float32}(), 
    "East Asia" => Dict{String, Float32}(), 
)

chart_data = Dict(
    "South Asia" => Dict{String, Vector{Union{Missing, Float32}}}(
        "005" => [],
        "005_var" => [],
        "006" => [],
        "006_var" => [],
        "061" => [],
        "061_var" => [],	
    ),
    "Southeast Asia" => Dict{String, Vector{Union{Missing, Float32}}}(
        "005" => [],
        "005_var" => [],
        "006" => [],
        "006_var" => [],
        "061" => [],
        "061_var" => [],	
    ),
    "Siberia" => Dict{String, Vector{Union{Missing, Float32}}}(
        "005" => [],
        "005_var" => [],
        "006" => [],
        "006_var" => [],
        "061" => [],
        "061_var" => [],	
    ),
    "East Asia" => Dict{String, Vector{Union{Missing, Float32}}}(
        "005" => [],
        "005_var" => [],
        "006" => [],
        "006_var" => [],
        "061" => [],
        "061_var" => [],	
    ),
)

areas = Array{Float32}(undef, (480, 360))
read!(areas_file, areas)
valid_areas = convert(Array{Union{Missing, Float32}}, areas)
replace!(valid_areas, -9999.0 => missing)

regions_array = Array{UInt8}(undef, (480, 360))
read!(mask_file, regions_array)
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

function get_monthly_vals(filepath, areas, sample_missing, region_name)
    occursin("c06", filepath) ? println(filepath) : nothing; 
	asia = Array{Float32}(undef, (480, 360, 12))
	read!(filepath, asia)
	# Restrict data to either Missing or Float32
	asia = convert(Array{Union{Missing, Float32}}, asia)
	# Replace -9999 values with missing
	replace!(asia, -999.0 => missing)
	# Apply Weights
	file_missing = findall(x -> ismissing(x), asia[:,:,1])
	result = valid_areas .* asia
	valid_areas[file_missing] .= missing
	total_area = sum(skipmissing(areas[regions[region_name]]))
	monthly_vals = Vector{Float32}()

	# For each month in result
	for i = 1:12
		# Sum all results by month to find monthly average
		append!(monthly_vals, sum(skipmissing(result[:,:,i][regions[region_name]]))/total_area)
	end
	return monthly_vals
end

function create_averages(areas, sample_missing, region_name)
	product_means = Dict(
			"005"=>Vector{Vector{Float64}}(),
			"006"=>Vector{Vector{Float64}}(),
			"061"=>Vector{Vector{Float64}}(),
	)
	
	# for each year
	for i in string.(collect(years))
        println(i)

		# For each version in each year
		for (k, v) in product_means
			ensemble = "AVERAGE"
			if k == "005"
				out = "out_c05"
			elseif k == "006"
				out = "out_c06"
			elseif k == "061"
				out = "out_c61"
			end

			filepath = @sprintf("./%s/MONTH_cor/GPP.ALL.%s.%s.bsq.flt", out, ensemble, i)
			if out == "out_c05" && i in string.(collect(2016:2020))
				continue
			end
			push!(v, get_monthly_vals(filepath, areas, sample_missing, region_name))
		end
	end
	return product_means
end

# make function to create weight and missing data.
    
sample_missing = get_sample_data()
valid_areas[sample_missing] .= missing

monthly_vals = undef
for region_name in region_names
    println(region_name)
    monthly_vals = create_averages(valid_areas, sample_missing, region_name)
    for (key, val) in monthly_vals
        chart_data[region_name][key] = mean.(val)
        # chart_data["GPP"][key] = mean.(val)
    end
end
# chart_data["GPP"]

TheilSenRegressor = @load TheilSenRegressor pkg=MLJScikitLearnInterface
ts_regr = TheilSenRegressor()
chart_data_df = Dict()
for (i, dataset) in enumerate(region_names)
    #SOMETHING WRONG HERE
    println(dataset)
    println(chart_data[dataset]["006"])
    limits = []
    mean005 = mean(chart_data[dataset]["005"][1:6])
    mean006 = mean(chart_data[dataset]["006"][1:6])
    mean061 = mean(chart_data[dataset]["061"][1:6])
    df = DataFrame("Years"=>2000:2020)
    for ver in versions
        # Calculate means for 2000-2005
        yearly_means[dataset][ver] = mean(chart_data[dataset][ver][1:6])
        anomaly = chart_data[dataset][ver] .- yearly_means[dataset][ver]
        anomaly = convert(Vector{Union{Float32, Missing}}, anomaly)
        while length(anomaly) < 21; push!(anomaly, missing) end
        df[!, ver] = anomaly
        # Train data for sens slope
        # 2000-2015
        ts_machine = machine(ts_regr, df[1:16, Cols("Years", ver)][:, [:Years]], df[:, Cols("Years", ver)][1:16, ver], scitype_check_level=0)
        fit!(ts_machine, verbosity=0)
        regr = predict_mode(ts_machine)
        regr = convert(Vector{Union{Float64, Missing}}, regr)
        push!(regr, missing,missing,missing,missing,missing)
        df[!, ver*"_2015_regr"] = regr
        #2000-2020
        ts_machine = machine(ts_regr, dropmissing(df[:, Cols("Years", ver)])[:, [:Years]], dropmissing(df[:, Cols("Years", ver)])[:, ver], scitype_check_level=0)
        fit!(ts_machine, verbosity=0)
        regr = predict_mode(ts_machine)
        if ver == "005" for i in 1:5 push!(regr, regr[end]+regr[end]-regr[end-1]) end end
        df[!, ver*"_2020_regr"] = regr
        
        chart_data_df[dataset] = df
    end
end

f = Figure(size = (1000, 650))

titles = ["Siberia" "South Asia"; 
        "Southeast Asia" "East Asia"]

for i in CartesianIndices(titles)
    Label(f[i[1], i[2]][0,1:2], titles[i], font=:bold, fontsize=20,)
end

# rowgap!(f.layout, 1[1], -100)

axs = [Axis(
        f[y,x][1,inner],
        title=(inner == 1 ? "2000-2015" : "2000-2020"),
        aspect=1,
        xlabel="Year", ylabel=rich("kgC m", superscript("2"), " year", superscript("-1")),
        xticks=2000:5:2020,
        xminorgridvisible=true, xminorticks=2000:2020,
        xlabelvisible=(y == 1 ? false : true),
        xticklabelsvisible=(y == 1 ? false : true),
        ylabelvisible=(x == 1 && inner == 1 ? true : false),
        yticklabelsvisible=(x == 1 && inner == 1 ? true : false),
        xlabelsize=16, ylabelsize=16,
        titlesize=axistitlesize, titlefont=:regular,
    ) for inner in 1:2 for x in 1:2 for y in 1:2]

linkyaxes!(axs[1], axs[2], axs[3], axs[4], axs[5], axs[6], axs[7], axs[8])

vers = ["005", "006", "061"]
begin
for (i_r, region) in enumerate(chart_data_df)
    colormap = Makie.wong_colors()
    axis_cartesian_idx = findall(x->x == region[1], titles)
    axis_idx = LinearIndices(titles)[axis_cartesian_idx][1]
    for (i_v, ver) in enumerate(vers)
        lines!(axs[axis_idx], convert(Vector{Float32},line_years[1:16]), chart_data_df[region[1]][:, ver][1:16], color=colormap[i_v], linewidth=linewidth, alpha=0.5)
        lines!(axs[axis_idx], convert(Vector{Float32},line_years), chart_data_df[region[1]][:, ver*"_2015_regr"], color=colormap[i_v], linewidth=reglinewidth, linestyle=linestyle)
    end
    for (i_v, ver) in enumerate(vers)
        # lines!(axs[axis_idx+4], convert(Vector{Float32},line_years), chart_data_df[region[1]][:, ver], color=colormap[i_v], linewidth=linewidth, alpha=0.5)
        lines!(axs[axis_idx+4], convert(Vector{Float32},line_years), chart_data_df[region[1]][:, ver*"_2020_regr"], color=colormap[i_v], linewidth=reglinewidth, linestyle=linestyle)
        
    end
end

for (i,ver) in enumerate(["C5", "C6", "C6.1"])
    colormap = Makie.wong_colors()
    Label(
        f[1,1][1,1], ver; halign=:left,valign=:top,height=i*27,
        fontsize=25,color=colormap[i],
        tellheight=false,tellwidth=false,
    )
end

resize_to_layout!(f)
f
end