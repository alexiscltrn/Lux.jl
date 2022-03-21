module ExplicitFluxLayers

using Statistics, Zygote, NNlib, CUDA, Random, Setfield
using Flux: Flux
import Flux:
    zeros32,
    ones32,
    glorot_normal,
    glorot_uniform,
    convfilter,
    expand,
    calc_padding,
    DenseConvDims,
    _maybetuple_string,
    reshape_cell_output

# Base Type
abstract type ExplicitLayer end

initialparameters(::AbstractRNG, ::ExplicitLayer) = NamedTuple()
initialparameters(l::ExplicitLayer) = initialparameters(Random.GLOBAL_RNG, l)
initialstates(::AbstractRNG, ::ExplicitLayer) = NamedTuple()
initialstates(l::ExplicitLayer) = initialstates(Random.GLOBAL_RNG, l)

function initialparameters(rng::AbstractRNG, l::NamedTuple)
    return NamedTuple{Tuple(collect(keys(l)))}(initialparameters.((rng,), values(l)))
end
initialstates(rng::AbstractRNG, l::NamedTuple) = NamedTuple{Tuple(collect(keys(l)))}(initialstates.((rng,), values(l)))

setup(rng::AbstractRNG, l::ExplicitLayer) = (initialparameters(rng, l), initialstates(rng, l))
setup(l::ExplicitLayer) = setup(Random.GLOBAL_RNG, l)

nestedtupleofarrayslength(t::Any) = 1
nestedtupleofarrayslength(t::AbstractArray) = length(t)
function nestedtupleofarrayslength(t::Union{NamedTuple,Tuple})
    length(t) == 0 && return 0
    return sum(nestedtupleofarrayslength, t)
end

parameterlength(l::ExplicitLayer) = parameterlength(initialparameters(l))
statelength(l::ExplicitLayer) = statelength(initialstates(l))
parameterlength(ps::NamedTuple) = nestedtupleofarrayslength(ps)
statelength(st::NamedTuple) = nestedtupleofarrayslength(st)

apply(model::ExplicitLayer, x, ps::NamedTuple, s::NamedTuple) = model(x, ps, s)

# Test Mode
function testmode(states::NamedTuple, mode::Bool=true)
    updated_states = []
    for (k, v) in pairs(states)
        if k == :training
            push!(updated_states, k => !mode)
            continue
        end
        push!(updated_states, k => testmode(v, mode))
    end
    return (; updated_states...)
end

testmode(x::Any, mode::Bool=true) = x

testmode(m::ExplicitLayer, mode::Bool=true) = testmode(initialstates(m), mode)

trainmode(x::Any, mode::Bool=true) = testmode(x, !mode)

# Utilities
zeros32(rng::AbstractRNG, args...; kwargs...) = zeros32(args...; kwargs...)
ones32(rng::AbstractRNG, args...; kwargs...) = ones32(args...; kwargs...)
Base.zeros(rng::AbstractRNG, args...; kwargs...) = zeros(args...; kwargs...)
Base.ones(rng::AbstractRNG, args...; kwargs...) = ones(args...; kwargs...)

include("norm_utils.jl")

# Layer Implementations
include("chain.jl")
include("batchnorm.jl")
include("linear.jl")
include("convolution.jl")
include("weightnorm.jl")
include("basics.jl")

# Transition to Explicit Layers
include("transform.jl")

# Pretty Printing
include("show_layers.jl")

end
