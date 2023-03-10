ENV["JULIA_PKG_DEVDIR"] = joinpath(homedir(), "julia", "packages")
ENV["JULIA_PKG_USE_CLI_GIT"] = "true"

@eval var"###M###" = Module()

@eval var"###M###" macro err(ex)
    return quote
        try
            Core.eval($(__module__), $(ex))
        catch err
            @error err
        end
    end |> esc
end

@eval var"###M###" atreplinit() do repl
    @err begin
        @eval using REPL
        isdefined(repl, :interface) || (repl.interface = REPL.setup_interface(repl))
    end

    @info "Loading OhMyREPL ..."
    @err @eval using OhMyREPL

    isdefined(Main, :Juno) && @err @eval Main include(normpath(@__DIR__, "junostartup.jl"))

    if occursin("DEV", string(VERSION))
        @info "Setting up Base development utilities ..."

        # useful alias
        @err @eval Main const CC = Core.Compiler

        # to use Infiltrator inside `Core.Compiler`
        @err @eval Core.Compiler begin
            const __Dict__ = Main.Dict
            getindex(d::__Dict__, args...) = Main.getindex(d, args...)
            setindex!(d::__Dict__, args...) = Main.setindex!(d, args...)
        end

        # Juno setup
        if isdefined(Main, :Atom)
            @err @eval Main.Atom begin
                Media.render(i::Inline, xs::Core.Compiler.BitSet) = Media.render(i, baseconvert(xs))
                Media.render(i::Inline, xs::Core.Compiler.IdSet) = Media.render(i, baseconvert(xs))
                Media.render(i::Inline, xs::Core.Compiler.IdDict) = Media.render(i, baseconvert(xs))

                baseconvert(@nospecialize x) = x
                baseconvert(xs::Core.Compiler.BitSet) = BitSet(Core.Compiler.collect(xs))
                function baseconvert(xs::T) where {T<:Core.Compiler.IdSet}
                    bxs = baseconvertT(T)()
                    for x in Core.Compiler.collect(xs)
                        push!(bxs, baseconvert(x))
                    end
                    return bxs
                end
                function baseconvert(xs::T) where {T<:Core.Compiler.IdDict}
                    bxs = baseconvertT(T)()
                    for (k, v) in Core.Compiler.collect(xs)
                        push!(bxs, baseconvert(k) => baseconvert(v))
                    end
                    bxs
                end
                baseconvert(xs::Tuple) = tuple((baseconvert(x) for x in xs)...)

                baseconvertT(@nospecialize T) = T
                baseconvertT(::Type{Core.Compiler.BitSet}) = BitSet
                baseconvertT(::Type{Core.Compiler.IdSet{T}}) where {T} = Base.IdSet{baseconvertT(T)}
                baseconvertT(::Type{Core.Compiler.IdDict{K,V}}) where {K,V} = Base.IdDict{baseconvertT(K),baseconvertT(V)}
                baseconvertT(::Type{T}) where {T<:Tuple} = Tuple{Any[baseconvertT(t) for t in T.parameters]...}
            end

            @err @eval Main.Atom handle("module") do data
                path = get(data, "path", "")

                # NOTE: special case `Core.Compiler`
                for compiler_path in (basepath("compiler"),
                                      "$(homedir())/julia/julia2/base/compiler",
                                      "$(homedir())/julia/julia3/base/compiler",
                                      )
                    if occursin(compiler_path, path)
                        if path == normpath(compiler_path, "ssair", "show.jl")
                            main = "Base"
                            sub  = "IRShow"
                        elseif path == normpath(compiler_path, "ssair", "EscapeAnalysis", "EAUtils.jl")
                            main = "Base"
                            sub  = "EAUtils"
                        elseif occursin("EscapeAnalysis", path)
                            main = "Core"
                            sub  = "Compiler.EscapeAnalysis"
                        else
                            main = "Core"
                            sub  = "Compiler"
                        end
                        return (;
                            main,
                            sub,
                            inactive    = false,
                            subInactive = false,
                        )
                    end
                end

                main::String, sub::String = modulenames(data, cursor(data))

                mod = CodeTools.getmodule(main)
                smod = CodeTools.getmodule(mod, sub)

                if main == "Main" && sub == ""
                    MAIN_MODULE_LOCATION[] = path, data["row"]
                end

                loaded_mods = copy(Base.loaded_modules_array())
                if main == "Main"
                    filter!(m -> string(m) == sub, loaded_mods)
                    if !isempty(loaded_mods)
                        return (
                        main        = string(loaded_mods[1]),
                        sub         = "",
                        inactive    = false,
                        subInactive = false
                        )
                    end
                end

                return (;
                    main        = main,
                    sub         = sub,
                    inactive    = mod === nothing,
                    subInactive = smod === nothing
                )
            end
        end
    end
end

# JET & JETLS
if !haskey(ENV, "JET_DEV_MODE")
    ENV["JET_DEV_MODE"] = true
end
if !haskey(ENV, "JETLS_DEV_MODE")
    ENV["JETLS_DEV_MODE"] = true
end
