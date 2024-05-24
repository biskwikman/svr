### A Pluto.jl notebook ###
# v0.19.42

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    quote
        local iv = try Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value catch; b -> missing; end
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : iv(el)
        el
    end
end

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

# ╔═╡ 588bb11e-0545-480f-9bfa-b8488af630ba
@bind years Select([2000:2015, 2000:2020])

# ╔═╡ ca07dd67-64b9-4842-93dc-727fd66cfdb8
begin
	colormap = :cork
	dataset = "gpp"

	colorrange = (-0.05, 0.05)
	colorgradient=cgrad(colormap, 15, categorical=true)
	ticks=[colorrange[1], colorrange[1]/2, 0, colorrange[2], colorrange[2]/2]
	tickformat = x -> string.(x)
end

# ╔═╡ 85e90138-4c75-49cc-85bb-99748102ecc9
begin
	function load_trend_array()
		f = jldopen("./svr_gpp_annual_spatial_trend_$(years[end]).jld2")
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
		colormap_label = L"kgC\; m^2\; year^{-1}"
		fig = Figure(resolution = (1400, 1200))
		ticklabelsize=45
		colorbarlabelsize=45
		titlesize=45
		colspacing=Relative(0.08)
		hm=undef
		rowspacing=Relative(-0.1)

		for (i, (ver, ax_loc)) in enumerate(zip(["V5", "V6", "V6.1"], [fig[1,1], fig[1,2], fig[2,1]]))
			ver == "V5" ? end_year = 2015 : end_year = years[end]
			ax = GeoAxis(ax_loc, title=ver*": 2000-$(end_year)",
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
			ticks=ticks, tickformat=tickformat,
			width=Relative(4/5),
			size=50,
		)
		
		Label(fig[0,:], replace(uppercase(dataset), "_"=>" ", "DAY"=>"Day", "NIGHT"=>"Night") * " Estimation: Interannual Trend", fontsize=50)
		# colgap!(fig.layout, 1, colspacing)
		rowgap!(fig.layout, 2, rowspacing)
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
# ╠═588bb11e-0545-480f-9bfa-b8488af630ba
# ╠═8cf4aae7-4471-4108-83cf-7e192c7e6b5e
# ╠═ca07dd67-64b9-4842-93dc-727fd66cfdb8
# ╠═8ef4242c-398c-4cd8-bbf9-d992caf68ded
# ╠═85e90138-4c75-49cc-85bb-99748102ecc9
# ╠═ad542e2e-cba9-11ee-1617-ed02db50a0fe
# ╠═1f787995-301f-4672-a821-643b8c757cf1
