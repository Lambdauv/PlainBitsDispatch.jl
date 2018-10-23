using PlainBitsDispatch
using Test

struct Y{T} end

@:: function f(::Y{T}; y::Bool, x=1) where T::Integer
    return x,y
end
@:: function f(::Y{T}; x=2.0) where T::AbstractFloat
    return x
end
@:: function f(::Y{::Bool}; x=false)
    return x
end
@:: function f(x::Int, ::Y{T}, z=10) where T::Complex
    return x+z+real(T)
end
@:: function f(::Y{T}, args...) where T::UInt8
    return +(args...)
end

@testset "Basic functionality" begin
    @test @inferred(f(Y{2}(), y=true)) == (1,true)
    @test @inferred(f(Y{2}(), y=true, x=2)) == (2,true)
    @test_throws MethodError f(Y{2}(), y=true, z=1)     # kw arguments we didn't allow
    @test_throws UndefKeywordError f(Y{2}())            # lacking required kw arguments

    @test @inferred(f(Y{2.0}())) === 2.0
    @test_throws MethodError f(Y{2.0}(); y=true)        # kw arguments from other methods

    @test @inferred(f(Y{true}())) === false

    @test @inferred(f(2, Y{1+im}())) === 13         # non-first position :: arg, opt args.
    @test_throws MethodError f(2, Y{1+im}(), x=10)      # undefined optional argument

    @test @inferred(f(Y{0x00}(), 1, 2, 3, 4, 5)) === 15
end
