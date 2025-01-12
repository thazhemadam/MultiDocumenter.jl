module MultiDocumenter

import Gumbo, AbstractTrees
using HypertextLiteral

"""
    SearchConfig(index_versions = ["stable"], engine = MultiDocumenter.FlexSearch)

`index_versions` is a vector of relative paths used for generating the search index. Only
the first matching path is considered.
`engine` may be `MultiDocumenter.FlexSearch`, `MultiDocumenter.Stork`, or a module that conforms
to the expected API (which is currently undocumented).
"""
Base.@kwdef mutable struct SearchConfig
    index_versions = ["stable", "dev"]
    engine = FlexSearch
end

struct MultiDocRef
    upstream::String

    path::String
    name::String

    # these are not actually used internally
    giturl::String
    branch::String
end

function MultiDocRef(; upstream, name, path, giturl = "", branch = "gh-pages")
    MultiDocRef(upstream, path, name, giturl, branch)
end

struct DropdownNav
    name::String
    children::Vector{MultiDocRef}
end

struct Column
    name
    children::Vector{MultiDocRef}
end

struct MegaDropdownNav
    name
    columns::Vector{Column}
end

struct BrandImage
    path::String
    imagepath::String
end

function walk_outputs(f, root, docs::Vector{MultiDocRef}, dirs::Vector{String})
    for ref in docs
        p = joinpath(root, ref.path)
        for dir in dirs
            dirpath = joinpath(p, dir)
            isdir(dirpath) || continue
            for (r, _, files) in walkdir(dirpath)
                for file in files
                    file == "index.html" || continue

                    f(chop(r, head = length(root), tail = 0), joinpath(r, file))
                end
            end
            break
        end
    end
end

include("renderers.jl")
include("search/flexsearch.jl")
include("search/stork.jl")

const DEFAULT_ENGINE = SearchConfig(index_versions = ["stable", "dev"], engine = FlexSearch)

"""
    make(
        outdir,
        docs::Vector{MultiDocRef};
        assets_dir,
        brand_image,
        custom_stylesheets = [],
        custom_scripts = [],
        search_engine = SearchConfig(),
        prettyurls = true
    )

Aggregates multiple Documenter.jl-based documentation pages `docs` into `outdir`.

- `assets_dir` is copied into `outdir/assets`
- `brand_image` is a `BrandImage(path, imgpath)`, which is rendered as the leftmost
  item in the global navigation
- `custom_stylesheets` is a `Vector{String}` of stylesheets injected into each page.
- `custom_scripts` is a `Vector{String}` of scripts injected into each page.
- `search_engine` inserts a global search bar if not `false`. See [`SearchConfig`](@ref) for more details.
- `prettyurls` removes all `index.html` suffixes from links in the global navigation.
"""
function make(
    outdir,
    docs::Vector;
    assets_dir = nothing,
    brand_image::Union{Nothing,BrandImage} = nothing,
    custom_stylesheets = [],
    custom_scripts = [],
    search_engine = DEFAULT_ENGINE,
    prettyurls = true,
)
    maybe_clone(flatten_multidocrefs(docs))

    dir = make_output_structure(flatten_multidocrefs(docs), prettyurls)
    out_assets = joinpath(dir, "assets")
    if assets_dir !== nothing && isdir(assets_dir)
        cp(assets_dir, out_assets)
    end
    isdir(out_assets) || mkpath(out_assets)
    cp(joinpath(@__DIR__, "..", "assets", "default"), joinpath(out_assets, "default"))

    if search_engine != false
        if search_engine.engine == Stork && !Stork.has_stork()
            @warn "stork binary not found. Falling back to flexsearch as search_engine."
            search_engine = DEFAULT_ENGINE
        end
    end

    inject_styles_and_global_navigation(
        dir,
        docs,
        brand_image,
        custom_stylesheets,
        custom_scripts,
        search_engine,
        prettyurls,
    )

    if search_engine != false
        search_engine.engine.build_search_index(dir, flatten_multidocrefs(docs), search_engine)
    end

    cp(dir, outdir; force = true)
    rm(dir; force = true, recursive = true)

    return outdir
end

function flatten_multidocrefs(docs::Vector)
    out = MultiDocRef[]
    for doc in docs
        if doc isa MultiDocRef
            push!(out, doc)
        elseif doc isa MegaDropdownNav
            for col in doc.columns
                for doc in col.children
                    push!(out, doc)
                end
            end
        else
            for doc in doc.children
                push!(out, doc)
            end
        end
    end
    out
end

function maybe_clone(docs::Vector{MultiDocRef})
    for doc in docs
        if !isdir(doc.upstream)
            @info "Upstream at $(doc.upstream) does not exist. `git clone`ing `$(doc.giturl)#$(doc.branch)`"
            run(`git clone --depth 1 $(doc.giturl) --branch $(doc.branch) --single-branch $(doc.upstream)`)
        end
    end
end

function make_output_structure(docs::Vector{MultiDocRef}, prettyurls)
    dir = mktempdir()

    for doc in docs
        outpath = joinpath(dir, doc.path)
        cp(doc.upstream, outpath; force = true)

        gitpath = joinpath(outpath, ".git")
        if isdir(gitpath)
            rm(gitpath, recursive = true)
        end
    end

    open(joinpath(dir, "index.html"), "w") do io
        println(
            io,
            """
                <!--This file is automatically generated by MultiDocumenter.jl-->
                <meta http-equiv="refresh" content="0; url=./$(string(first(docs).path, prettyurls ? "/" : "/index.html"))"/>
            """,
        )
    end

    return dir
end

function make_global_nav(
    dir,
    docs::Vector,
    thispagepath,
    brand_image,
    search_engine,
    prettyurls,
)
    nav = @htl """
    <nav id="multi-page-nav">
        $(render(brand_image, dir, thispagepath))
        <div id="nav-items" class="hidden-on-mobile">
            $([render(doc, dir, thispagepath, prettyurls) for doc in docs])
            $(search_engine.engine.render())
        </div>
        <a id="multidoc-toggler"></a>
    </nav>
    """

    return htl_to_gumbo(nav)
end

function make_global_stylesheet(custom_stylesheets, path)
    out = []

    for stylesheet in custom_stylesheets
        style = Gumbo.HTMLElement{:link}(
            [],
            Gumbo.NullNode(),
            Dict(
                "rel" => "stylesheet",
                "type" => "text/css",
                "href" => joinpath(path, stylesheet),
            ),
        )
        push!(out, style)
    end

    return out
end

function make_global_scripts(custom_scripts, path)
    out = []

    for script in custom_scripts
        js = Gumbo.HTMLElement{:script}(
            [],
            Gumbo.NullNode(),
            Dict(
                "src" => joinpath(path, script),
                "type" => "text/javascript",
                "charset" => "utf-8",
            ),
        )
        push!(out, js)
    end

    return out
end

function js_injector()
    return read(joinpath(@__DIR__, "..", "assets", "multidoc_injector.js"), String)
end


function inject_styles_and_global_navigation(
    dir,
    docs::Vector,
    brand_image,
    custom_stylesheets,
    custom_scripts,
    search_engine,
    prettyurls,
)

    if search_engine != false
        search_engine.engine.inject_script!(custom_scripts)
        search_engine.engine.inject_styles!(custom_stylesheets)
    end
    pushfirst!(custom_stylesheets, joinpath("assets", "default", "multidoc.css"))

    for (root, _, files) in walkdir(dir)
        for file in files
            path = joinpath(root, file)
            if file == "documenter.js"
                open(path, "a") do io
                    println(io, js_injector())
                end
                continue
            end

            endswith(file, ".html") || continue

            islink(path) && continue
            isfile(path) || continue

            stylesheets = make_global_stylesheet(custom_stylesheets, relpath(dir, root))
            scripts = make_global_scripts(custom_scripts, relpath(dir, root))


            page = read(path, String)
            if startswith(
                page,
                "<!--This file is automatically generated by Documenter.jl-->",
            )
                continue
            end
            doc = Gumbo.parsehtml(page)
            injected = 0

            for el in AbstractTrees.PreOrderDFS(doc.root)
                injected >= 2 && break

                if el isa Gumbo.HTMLElement
                    if Gumbo.tag(el) == :head
                        for stylesheet in stylesheets
                            stylesheet.parent = el
                            push!(el.children, stylesheet)
                        end
                        for script in scripts
                            script.parent = el
                            pushfirst!(el.children, script)
                        end
                        injected += 1
                    elseif Gumbo.tag(el) == :body && !isempty(el.children)
                        documenter_div = first(el.children)
                        if documenter_div isa Gumbo.HTMLElement &&
                           Gumbo.getattr(documenter_div, "id", "") == "documenter"
                            @debug "Could not detect Documenter page layout in $path. This may be due to an old version of Documenter."
                        end
                        # inject global navigation as first element in body

                        global_nav = make_global_nav(
                            dir,
                            docs,
                            root,
                            brand_image,
                            search_engine,
                            prettyurls,
                        )
                        global_nav.parent = el
                        pushfirst!(el.children, global_nav)
                        injected += 1
                    end
                end
            end

            open(path, "w") do io
                print(io, doc)
            end
        end
    end
end

end