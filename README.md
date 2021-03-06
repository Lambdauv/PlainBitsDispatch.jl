[![Build Status](https://travis-ci.org/ajkeller34/PlainBitsDispatch.jl.svg?branch=master)](https://travis-ci.org/ajkeller34/PlainBitsDispatch.jl)

# PlainBitsDispatch.jl

Julia lets you use "plain bits" values (types like `Int`, `Float64`, etc.) as type
parameters. In some cases (probably a vanishingly small number of cases?), you may want
to dispatch on the types of those values. There is no mechanism to do this out of the box,
although it is possible to achieve in effect by defining a few auxiliary methods.

This package provides one macro, `@::`, which lets you define such methods easily.
Keyword arguments and optional arguments are handled somewhat gracefully.

## Examples

Let's first define a struct with a free type parameter:

```
julia> struct Y{T} end
```

Then, there are two ways to use this package. Option 1:

```
julia> @:: function f(::Y{T}) where T::Integer
    println(T)
end
_::_f (generic function with 1 method)

julia> f(Y{42}())
42
```

Option 2 is a shorthand syntax, for when you don't care about the value:

```
julia> @:: function f(::Y{::Float64})
    println("Got a float")
end
_::_f (generic function with 2 methods)

julia> f(Y{2.0}())
Got a float

julia> f(Y{42}())
42
```

## Caveats

- Defining a method like e.g. `@:: function f(::Y{::Float64})` or
`@:: function f(::Y{T}) where T::Float64` will actually define a method
`function f(::Y{T}) where T`, so if you've defined that already or plan to define it, you
will run into trouble. You can get around this to some extent by defining
`@:: function f(::Y{::Type})` though perhaps the behavior is not exactly the same.
- You can't define type aliases. For example, `@:: Z = Y{::Int}` does not and cannot work without changes to Julia.

## How does it work?

Omitting some output clutter, we have:

```
julia> @macroexpand begin
    @:: function h(::Y{T}, z=3; y::Bool, x::Int=3) where T::Float64
        println("do stuff")
    end
end
quote
    begin
        function (h(##401::Y{T}, args...; kwargs...)::Any) where T
            return _::_h(T, ##401, args...; kwargs...)
        end
        function (_::_h(::Float64, ##401::Y{T}, z=3; y::Bool, x::Int=3)::Any) where T
            begin
                println("do stuff")
            end
        end
    end
end
```
