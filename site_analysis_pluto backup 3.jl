### A Pluto.jl notebook ###
# v0.19.26

using Markdown
using InteractiveUtils

# ╔═╡ b3dd68ba-8512-11ee-367a-e5bba69e1e78
begin
	using CSV
	using DataFrames
	using CairoMakie
	using GLM
	using Printf
	using Statistics
	using StatsBase
	using StatsMakie
end

# ╔═╡ a1c16bf8-5cde-46ca-be3e-fe9bdd9d4406
begin
	site_stats_df = DataFrame(ensemble=String[], r_squared=Float32[], RMSE=Float32[])
	gpps::Vector{Vector{Float64}} = []
	y_i = []
	for ens in 201:210
		output_file = @sprintf("./CROSSVAL/output_lvmar/CV_%i_ALL_GPP.csv", ens)
		input_df = DataFrame(CSV.File("./prep_input/svr.test.ALL.GPP.201.txt", header=false))
		output_df = DataFrame(CSV.File(output_file, header=false))
	
		input_df[!, "id"] = string.(input_df[:, 1], "_", input_df[:, 2], "_", input_df[:, 3])
		output_df[!, "id"] = string.(output_df[:, 3], "_", output_df[:, 4], "_", output_df[:, 5])
	
		# For some reason there were some records in both dfs that did not match, delete them
		filter!("id" => x -> x in output_df[!, "id"], input_df)
		filter!("id" => x -> x in input_df[!, "id"], output_df)

		y_i = input_df[:,5]
		y_o = output_df[:,1]

		r_squared = cor(y_o, y_i)^2
		rmse = rmsd(y_o, y_i)

		push!(gpps, y_o)
		push!(site_stats_df, [string(ens-200), r_squared, rmse])
	end
	y_o = mean(gpps)
	mean_gpp_cor = cor(y_o, y_i)^2
	mean_gpp_rmsd = rmsd(y_o, y_i)
	push!(site_stats_df, ["Ensemble Mean", mean_gpp_cor, mean_gpp_rmsd])
	site_stats_df
end

# ╔═╡ 97fce899-bdf2-4afa-9851-7a9ec1ba408b
begin
df = DataFrame(x = y_i, Y = y_o)
model = lm(@formula(Y ~ x), df)
end

# ╔═╡ cf17f699-8703-4fab-ac58-583c0fb65db6
begin
	f = Figure()
	ax = Axis(f[1, 1])
	scatter!(ax, y_o, y_i; markersize=3)
	# lines!(ax, length(linear_model), linear_model)
	f
end

# ╔═╡ 2d8753b7-b58b-4532-827e-cc03b00f04f1
html"""<style>
main {
    max-width: 1500px;
    margin-left: 50px;
}
"""

# ╔═╡ Cell order:
# ╠═b3dd68ba-8512-11ee-367a-e5bba69e1e78
# ╠═a1c16bf8-5cde-46ca-be3e-fe9bdd9d4406
# ╠═97fce899-bdf2-4afa-9851-7a9ec1ba408b
# ╠═cf17f699-8703-4fab-ac58-583c0fb65db6
# ╠═2d8753b7-b58b-4532-827e-cc03b00f04f1
