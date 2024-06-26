# Return the `i`-th column of the array `A` as an `SVector`.
@inline function extract_svector(A, ::Val{NDIMS}, i) where {NDIMS}
    return SVector(ntuple(@inline(dim->A[dim, i]), NDIMS))
end

# When particles end up with coordinates so big that the cell coordinates
# exceed the range of Int, then `floor(Int, i)` will fail with an InexactError.
# In this case, we can just use typemax(Int), since we can assume that particles
# that far away will not interact with anything, anyway.
# This usually indicates an instability, but we don't want the simulation to crash,
# since adaptive time integration methods may detect the instability and reject the
# time step.
# If we threw an error here, we would prevent the time integration method from
# retrying with a smaller time step, and we would thus crash perfectly fine simulations.
@inline function floor_to_int(i)
    if isnan(i) || i > typemax(Int)
        return typemax(Int)
    elseif i < typemin(Int)
        return typemin(Int)
    end

    return floor(Int, i)
end

"""
    @threaded for ... end

Semantically the same as `Threads.@threads` when iterating over a `AbstractUnitRange`
but without guarantee that the underlying implementation uses `Threads.@threads`
or works for more general `for` loops.
In particular, there may be an additional check whether only one thread is used
to reduce the overhead of serial execution or the underlying threading capabilities
might be provided by other packages such as [Polyester.jl](https://github.com/JuliaSIMD/Polyester.jl).

!!! warn
    This macro does not necessarily work for general `for` loops. For example,
    it does not necessarily support general iterables such as `eachline(filename)`.

Some discussion can be found at
[https://discourse.julialang.org/t/overhead-of-threads-threads/53964](https://discourse.julialang.org/t/overhead-of-threads-threads/53964)
and
[https://discourse.julialang.org/t/threads-threads-with-one-thread-how-to-remove-the-overhead/58435](https://discourse.julialang.org/t/threads-threads-with-one-thread-how-to-remove-the-overhead/58435).

Copied from [Trixi.jl](https://github.com/trixi-framework/Trixi.jl).
"""
macro threaded(expr)
    # Use `esc(quote ... end)` for nested macro calls as suggested in
    # https://github.com/JuliaLang/julia/issues/23221
    #
    # The following code is a simple version using only `Threads.@threads` from the
    # standard library with an additional check whether only a single thread is used
    # to reduce some overhead (and allocations) for serial execution.
    #
    # return esc(quote
    #   let
    #     if Threads.nthreads() == 1
    #       $(expr)
    #     else
    #       Threads.@threads $(expr)
    #     end
    #   end
    # end)
    #
    # However, the code below using `@batch` from Polyester.jl is more efficient,
    # since this packages provides threads with less overhead. Since it is written
    # by Chris Elrod, the author of LoopVectorization.jl, we expect this package
    # to provide the most efficient and useful implementation of threads (as we use
    # them) available in Julia.
    # !!! danger "Heisenbug"
    #     Look at the comments for `wrap_array` when considering to change this macro.

    return esc(quote
                   PointNeighbors.@batch $(expr)
               end)
end
