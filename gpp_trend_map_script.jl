using CairoMakie	
using GeoMakie 
using JLD2 
using Statistics

println("begin")

years = 2000:2020

colormap = :Spectral_11
colormap_diff = :PuOr_11
dataset = "gpp"

colorrange = (-0.05, 0.05)
colorgradient=cgrad(colormap, 11, categorical=true, rev=true)
colorgradient_diff = cgrad(colormap_diff, 11, categorical=true, rev=true)
ticks=[colorrange[1], colorrange[1]/2, 0, colorrange[2], colorrange[2]/2]
tickformat = x -> string.(x)

function load_trend_array(end_year::String)
    f = jldopen("./svr_gpp_annual_spatial_trend_$(end_year).jld2")
    trend_array = f[dataset]
    trend_array = convert(Array{Union{Missing, Float32}}, trend_array)
    replace!(trend_array, -9999.0 => missing)
    return trend_array
end

trend_array_2020 = load_trend_array("2020")
trend_array_2015 = load_trend_array("2015")

function create_figure(trend_array::Array)
    colormap_label = L"kgC\; m^2\; year^{-1}"
    fig = Figure(size = (1000, 1200))
    ticklabelsize=35
    colorbarlabelsize=45
    titlesize=35
    hm=undef

    for (i, (ver, ax_loc, array_index, end_year)) in enumerate(zip(["C5", "C6", "C6", "C6.1", "C6.1"], [fig[1,1], fig[2,1], fig[2,2], fig[3,1], fig[3,2]], [1,2,2,3,3],[2015,2015,2020,2015,2020]))
    end_year == 2015 ? trend_data = trend_array_2015 : trend_data = trend_array_2020
        ax = Axis(ax_loc, title=ver*": 2000-$(end_year)",
            xticklabelsvisible=false,
            yticklabelsvisible=false,
            xticksvisible=false,
            yticksvisible=false,
            limits=((60, 180), (-10, 80)),
            titlesize=titlesize,
            aspect=DataAspect()
        )
        poly!(ax, GeoMakie.land(), color=:gray)
        hm = heatmap!(ax, 60..180, -10..80, trend_data[:,:,array_index]; colorrange=colorrange, colormap=colorgradient)
        lines!(ax, GeoMakie.coastlines(), color=:gray, linewidth=0.5)
    end

    Colorbar(
        fig[1,2][1,:], hm, tellwidth=false, tellheight=false, vertical=false,
        ticklabelsize=ticklabelsize, label=colormap_label, labelsize=colorbarlabelsize,
        ticks=ticks, tickformat=tickformat,
        width=Relative(4/5),
        size=50,
    )
    return fig
end
# create_figure(trend_array_2020)
# save("/home/dan/Documents/modis_svr_paper/graphics/svr_maps.png", create_figure(trend_array_2020))

function create_differential_maps(trend_array::Array)
    colormap_label = L"kgC\; m^2\; year^{-1}"
    ticklabelsize=40
    colorbarlabelsize=40
    titlesize=40
    colspacing=Relative(0.08)
    hm=undef
    rowspacing=Relative(-0.1)
    fig = Figure(size = (1200, 800))
    
    ax1 = Axis(fig[1,1], title="Change from C5 to C6",
            xticklabelsvisible=false,
            yticklabelsvisible=false,
            xticksvisible=false,
            yticksvisible=false,
            limits=((60, 180), (-10, 80)),
            titlesize=titlesize,
            aspect=DataAspect()
        )
    ax2 = Axis(fig[1,2], title="Change from C6 to C6.1",
            xticklabelsvisible=false,
            yticklabelsvisible=false,
            xticksvisible=false,
            yticksvisible=false,
            limits=((60, 180), (-10, 80)),
            titlesize=titlesize,
            aspect=DataAspect()
        )
    
    poly!(ax1, GeoMakie.land(), color=:gray)
    poly!(ax2, GeoMakie.land(), color=:gray)
    hm = heatmap!(ax1, 60..180, -10..80, trend_array_2015[:,:,2]
    - trend_array_2015[:,:,1];
    colorrange=colorrange, colormap=colorgradient_diff
    )
    heatmap!(ax2, 60..180, -10..80, trend_array_2020[:,:,3]
    - trend_array_2020[:,:,2];
    colorrange=colorrange, colormap=colorgradient_diff
    )
    lines!(ax1, GeoMakie.coastlines(), color=:gray, linewidth=0.5)
    lines!(ax2, GeoMakie.coastlines(), color=:gray, linewidth=0.5)

    Colorbar(
        fig[1,1:2][2,1], colorrange=colorrange, colormap=colorgradient_diff,
        labelsize=45,
        label=colormap_label,
        vertical=false,
        ticklabelsize=ticklabelsize,
        ticks=ticks, tickformat=tickformat,
        width=Relative(4/5),
        flipaxis=false,
        size=40,
    )

    return fig
end
create_differential_maps(trend_array_2020)
save("/home/dan/Documents/modis_svr_paper/graphics/svr_maps_diff.png")