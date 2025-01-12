using MultiDocumenter
using Test

@testset "MultiDocumenter.jl" begin
    clonedir = mktempdir()

    docs = [
        MultiDocumenter.DropdownNav("Debugging", [
            MultiDocumenter.MultiDocRef(
                upstream = joinpath(clonedir, "Infiltrator"),
                path = "inf",
                name = "Infiltrator",
                giturl = "https://github.com/JuliaDebug/Infiltrator.jl.git",
            ),
            MultiDocumenter.MultiDocRef(
                upstream = joinpath(clonedir, "JuliaInterpreter"),
                path = "debug",
                name = "JuliaInterpreter",
                giturl = "https://github.com/JuliaDebug/JuliaInterpreter.jl.git",
            ),
        ]),
        MultiDocumenter.MegaDropdownNav("Mega Debugger", [
            MultiDocumenter.Column("Column 1", [
                MultiDocumenter.MultiDocRef(
                    upstream = joinpath(clonedir, "Infiltrator"),
                    path = "inf",
                    name = "Infiltrator",
                    giturl = "https://github.com/JuliaDebug/Infiltrator.jl.git",
                ),
                MultiDocumenter.MultiDocRef(
                    upstream = joinpath(clonedir, "JuliaInterpreter"),
                    path = "debug",
                    name = "JuliaInterpreter",
                    giturl = "https://github.com/JuliaDebug/JuliaInterpreter.jl.git",
                ),
            ]),
            MultiDocumenter.Column("Column 2", [
                MultiDocumenter.MultiDocRef(
                    upstream = joinpath(clonedir, "Infiltrator"),
                    path = "inf",
                    name = "Infiltrator",
                    giturl = "https://github.com/JuliaDebug/Infiltrator.jl.git",
                ),
                MultiDocumenter.MultiDocRef(
                    upstream = joinpath(clonedir, "JuliaInterpreter"),
                    path = "debug",
                    name = "JuliaInterpreter",
                    giturl = "https://github.com/JuliaDebug/JuliaInterpreter.jl.git",
                ),
            ]),
        ]),
        MultiDocumenter.MultiDocRef(
            upstream = joinpath(clonedir, "DataSets"),
            path = "data",
            name = "DataSets",
            giturl = "https://github.com/JuliaComputing/DataSets.jl.git",
            # or use ssh instead for private repos:
            # giturl = "git@github.com:JuliaComputing/DataSets.jl.git",
        ),
    ]

    outpath = joinpath(@__DIR__, "out")

    MultiDocumenter.make(
        outpath,
        docs;
        search_engine = MultiDocumenter.SearchConfig(
            index_versions = ["stable", "dev"],
            engine = MultiDocumenter.FlexSearch
        )
    )

    @testset "flexsearch" begin
        @test isdir(outpath, "inf")
        @test isdir(outpath, "inf", "stable")
        @test isfile(outpath, "inf", "stable", "index.html")

        @test read(joinpath(outpath, "inf", "index.html"), String) == """
        <!--This file is automatically generated by Documenter.jl-->
        <meta http-equiv="refresh" content="0; url=./stable/"/>
        """

        @test isdir(outpath, "search-data")
        store_content = read(joinpath(outpath, "search-data", "store.json"), String)
        @test !isempty(store_content)
        @test occursin("Infiltrator.jl", store_content)
        @test occursin("@infiltrate", store_content)
        @test occursin("/inf/stable/", store_content)
        @test !occursin("/inf/dev/", store_content)
    end

    rm(outpath, recursive=true, force=true)
    rm(clonedir, recursive=true, force=true)
end
