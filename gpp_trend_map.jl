### A Pluto.jl notebook ###
# v0.19.42

using Markdown
using InteractiveUtils

# ╔═╡ ad542e2e-cba9-11ee-1617-ed02db50a0fe
begin
    import Pkg
    # activate a temporary environment
    Pkg.activate(mktempdir())
    Pkg.add([
        Pkg.PackageSpec(name="CairoMakie", version="0.10.12"),
        Pkg.PackageSpec(name="GeoMakie", version="0.5.1"),
		Pkg.PackageSpec(name="JLD2", version="0.4.45"),
		Pkg.PackageSpec(name="PlutoUI", version="0.7.55"),
    ])
    using CairoMakie, GeoMakie, JLD2, PlutoUI, Statistics
end

# ╔═╡ ca07dd67-64b9-4842-93dc-727fd66cfdb8
begin
	colormap = :cork
	dataset = "gpp"

	colorrange = (-0.05, 0.05)
	colorgradient=cgrad(colormap, 15, categorical=true)
	ticks=[colorrange[1], colorrange[1]/2, 0, colorrange[2], colorrange[2]/2]
end

# ╔═╡ 85e90138-4c75-49cc-85bb-99748102ecc9
begin
	function load_trend_array()
		f = jldopen("./Annual_GPP_Trend.jld2")
		trend_array = f[dataset]
		trend_array = convert(Array{Union{Missing, Float32}}, trend_array)
		replace!(trend_array, -9999.0 => missing)
		return trend_array
	end
	trend_array = load_trend_array()
	# nothing
end

# ╔═╡ 8cf4aae7-4471-4108-83cf-7e192c7e6b5e
begin
	function create_maps(trend_array)
		

		# dataset ∉ ("lst_day", "lst_night") ? colormap_label = L"%$(uppercase(dataset))\; year^{-1}" : colormap_label = L"°C\; year^{-1}"
		# colormap_label = rich("GPP kgC m",superscript("-2"),"year",superscript("-1")," ")
		colormap_label = L"kgC\; m^2\; year^{-1}"
		
		fig = Figure(resolution = (1400, 1200))
		ticklabelsize=45
		colorbarlabelsize=45
		titlesize=45
		colspacing=Relative(0.08)
		hm=undef

		for (i, (ver, ax_loc)) in enumerate(zip(["v5", "v6", "v6.1"], [fig[1,1], fig[1,2], fig[2,1]]))
			ax = GeoAxis(ax_loc, title="v05: 2000-2015",
				dest = "+proj=longlat",
				xticklabelsvisible=false,
				yticklabelsvisible=false,
				xticksvisible=false,
				yticksvisible=false,
				limits=((60, 180), (-10, 80)),
				titlesize=titlesize,
				xgridvisible=false,
				ygridvisible=false,
			)
			hidedecorations!(ax)

			hm = heatmap!(ax, 60..180, -10..80, trend_array[:,:,i]; colorrange=colorrange, colormap=colorgradient)
			lines!(ax, GeoMakie.coastlines(), color=:gray)
		end

		digits = 3
		
		Colorbar(
			fig[2,2][1,:], hm, tellwidth=false, tellheight=false, vertical=false,
			ticklabelsize=ticklabelsize, label=colormap_label, labelsize=colorbarlabelsize,
			ticks=ticks,
			width=Relative(4/5),
		)
		
		Label(fig[0,:], replace(uppercase(dataset), "_"=>" ", "DAY"=>"Day", "NIGHT"=>"Night") * " Estimation: Interannual Trend", fontsize=50)
		# colgap!(fig.layout, 1, colspacing)
		# resize_to_layout!(fig)
		return fig
	end
	create_maps(trend_array)
end

# ╔═╡ 8ef4242c-398c-4cd8-bbf9-d992caf68ded
begin
	trend_min = minimum(skipmissing(trend_array))
	trend_max = maximum(skipmissing(trend_array))
	min_mag = sqrt(trend_min * trend_min)
	max_mag = sqrt(trend_max * trend_max)
	min_mag < max_mag ? range_max = max_mag : range_max = min_mag
	range_min = range_max * -1
	maximum(skipmissing(trend_array[:,:,3]))
end

# ╔═╡ 1f787995-301f-4672-a821-643b8c757cf1
html"""<style>
main {
    max-width: 75%;
    margin-left: 1%;
    margin-right: 20% !important;
}
"""

# ╔═╡ Cell order:
# ╠═8cf4aae7-4471-4108-83cf-7e192c7e6b5e
# ╠═ca07dd67-64b9-4842-93dc-727fd66cfdb8
# ╠═8ef4242c-398c-4cd8-bbf9-d992caf68ded
# ╠═85e90138-4c75-49cc-85bb-99748102ecc9
# ╠═ad542e2e-cba9-11ee-1617-ed02db50a0fe
# ╠═1f787995-301f-4672-a821-643b8c757cf1
