module SIMDBenchmarks

import ..BaseBenchmarks
using ..BenchmarkTrackers
using ..RandUtils

###########
# Methods #
###########

function perf_axpy!(a, X, Y)
    # LLVM's auto-vectorizer typically vectorizes this loop even without @simd
    @simd for i in eachindex(X)
        @inbounds Y[i] += a*X[i]
    end
    return Y
end

function perf_inner(X, Y)
    s = zero(eltype(X))
    @simd for i in eachindex(X)
        @inbounds s += X[i]*Y[i]
    end
    return s
end

function perf_sum_reduce(X)
    s = zero(eltype(X))
    i = div(length(X), 4)
    j = div(length(X), 2)
    @simd for k in i:j
        @inbounds s += X[k]
    end
    return s
end

function perf_manual_example!(X, Y, Z)
    s = zero(eltype(Z))
    n = min(length(X),length(Y),length(Z))
    @simd for i in 1:n
        @inbounds begin
            Z[i] = X[i]-Y[i]
            s += Z[i]*Z[i]
        end
    end
    return s
end

function perf_two_reductions(X, Y, Z)
    # Use non-zero initial value to make sure reduction values include it.
    (s,t) = (one(eltype(X)), one(eltype(Y)))
    @simd for i in 1:length(Z)
        @inbounds begin
            s += X[i]
            t += 2*Y[i]
            s += Z[i]   # Two reductions go into s
        end
    end
    return (s,t)
end

function perf_conditional_loop!(X, Y, Z)
    # SIMD loop with a long conditional expression
    @simd for i=1:length(X)
        @inbounds begin
            X[i] = Y[i] * (Z[i] > Y[i]) * (Z[i] < Y[i]) * (Z[i] >= Y[i]) * (Z[i] <= Y[i])
        end
    end
    return X
end

function perf_local_arrays(V)
    # SIMD loop on local arrays declared without type annotations
    T, n = eltype(V), length(V)
    X = samerand(T, n)
    Y = samerand(T, n)
    Z = samerand(T, n)
    @simd for i in eachindex(X)
        @inbounds X[i] = Y[i] * Z[i]
    end
    return X
end

immutable ImmutableFields{V<:AbstractVector}
    X::V
    Y::V
    Z::V
end

ImmutableFields{V}(X::V) = ImmutableFields{V}(X, X, X)

type MutableFields{V<:AbstractVector}
    X::V
    Y::V
    Z::V
end

MutableFields{V}(X::V) = ImmutableFields{V}(X, X, X)

function perf_loop_fields!(obj)
    # SIMD loop with field access
    @simd for i = 1:length(obj.X)
        @inbounds obj.X[i] = obj.Y[i] * obj.Z[i]
    end
    return obj
end

##############
# Benchmarks #
##############

const SIZES = (9, 10, 255, 256, 999, 1000)
const Ts = (Int32, Int64, Float32, Float64)

@track BaseBenchmarks.TRACKER "simd" begin
    @benchmarks begin
        [(:axpy!, string(T), n) => perf_axpy!(samerand(T), randvec(T, n), randvec(T, n)) for n in SIZES, T in Ts]
        [(:inner, string(T), n) => perf_inner(randvec(T, n), randvec(T, n)) for n in SIZES, T in Ts]
        [(:sum_reduce, string(T), n) => perf_sum_reduce(randvec(T, n)) for n in SIZES, T in Ts]
        [(:manual_example!, string(T), n) => perf_manual_example!(randvec(T, n), randvec(T, n), randvec(T, n)) for n in SIZES, T in Ts]
        [(:two_reductions, string(T), n) => perf_two_reductions(randvec(T, n), randvec(T, n), randvec(T, n)) for n in SIZES, T in Ts]
        [(:conditional_loop!, string(T), n) => perf_conditional_loop!(randvec(T, n), randvec(T, n), randvec(T, n)) for n in SIZES, T in Ts]
        [(:local_arrays, string(T), n) => perf_local_arrays(randvec(T, n)) for n in SIZES, T in Ts]
        [(:loop_fields!, string(T), string(F), n) => perf_loop_fields!(F(randvec(T, n))) for n in SIZES, T in Ts, F in (MutableFields, ImmutableFields)]
    end
    @tags "array" "inbounds" "mul" "axpy!" "inner" "sum" "reduce"
end

end # module
