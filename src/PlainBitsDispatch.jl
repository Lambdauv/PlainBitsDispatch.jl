module PlainBitsDispatch

using MacroTools: splitdef, combinedef, @capture
export @::

@eval macro $(Symbol("::"))(ex)
    restrictions = Any[]    # Type restrictions on the args before the user-provided args in the helper function.
    dispatchsyms = Any[]    # Symbols preceding the user-provided args in the helper function.
    argsyms = Any[]         # Symbols we will use as args in the helper function.
    newvvarsyms = Any[]     # SomeType{::Float64} --> SomeType{T}; T goes in newvvarsyms.

    def = splitdef(ex)

    # Rewrite def[:args] to make sure all arguments are named and collect the argument
    # names in `argsyms`.
    maindefargs = Any[]
    helperdefargs = Any[]
    for y in def[:args]
        if (@capture(y, z_::T_{P__}) || @capture(y, ::T_{P__}))
            # Some argument found with type parameters.
            # Replace the ones that look like ::SomeType with a symbol (becomes a TypeVar)
            P = replace_vvars(P, newvvarsyms, restrictions)
            if z !== nothing
                # the argument had a name, keep track of it
                push!(argsyms, z)
                push!(maindefargs, :($z::$T{$(P...)}))
                push!(helperdefargs, :($z::$T{$(P...)}))
            else
                # give the argument a name and keep track of it
                a = gensym()
                push!(argsyms, a)
                push!(maindefargs, :($a::$T{$(P...)}))
                push!(helperdefargs, :($a::$T{$(P...)}))
            end
        elseif @capture(y, ::T_)
            # Argument without type parameters, but lacking a name.
            # give the argument a name and keep track of it
            a = gensym()
            push!(argsyms, a)
            push!(maindefargs, :($a::$T))
            push!(helperdefargs, :($a::$T))
        elseif @capture(y, z_::T_)
            # the argument had a name, keep track of it
            push!(argsyms, z)
            push!(maindefargs, y)
            push!(helperdefargs, y)
        elseif @capture(y, z_=N_)
            # optional argument
            push!(helperdefargs, y)
        elseif @capture(y, z_...)
            # optional varargs
            push!(helperdefargs, y)
        else
            error("unhandled function argument in @:: definition.")
        end
    end
    push!(maindefargs, :(args...))
    push!(argsyms, :(args...))

    # Rewrite where parameters to strip the e.g. `T::Int` restrictions.
    # Collect the `::Int` in `restrictions` and the `T` symbols in `dispatchsyms`.
    def[:whereparams] =
        Any[@capture(y, z_::T_) ?
                (push!(restrictions, :(::$T));
                 push!(dispatchsyms, z);
                 z) : y for y in def[:whereparams]]
    append!(def[:whereparams], newvvarsyms)
    append!(dispatchsyms, newvvarsyms)

    subfn = Symbol("_::_", def[:name])
    oldbody = def[:body]
    oldkwargs = def[:kwargs]
    def[:body] = :(return ($subfn)($(dispatchsyms...), $(argsyms...); kwargs...))
    def[:args] = maindefargs
    def[:kwargs] = Any[:(kwargs...)]
    mainfn = combinedef(def)

    # with some minor modifications, define the helper function.
    def[:body] = oldbody
    def[:name] = subfn
    def[:args] = helperdefargs
    def[:kwargs] = oldkwargs
    prepend!(def[:args], restrictions)
    helperfn = combinedef(def)

    esc(quote
        $(mainfn)
        $(helperfn)
    end)
end

function replace_vvars(vars, newvvarsyms, restrictions)
    return [@capture(var, ::T_) ?
        (g = gensym();
         push!(newvvarsyms, g);
         push!(restrictions, :(::$T));
         g) : var for var in vars]
end

end # module
