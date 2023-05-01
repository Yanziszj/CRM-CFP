##################################################################
## Basic Functions for Ellipsoids tests and plots
##################################################################
using CSV
using DataFrames
using BenchmarkProfiles
using BenchmarkTools
using LazySets
import LazySets: Ellipsoid
import Base: in
"""
Structure of an Ellipsoid satisfying dot(x,A*x) + 2*dot(b,x) ≤ α
"""
@kwdef struct EllipsoidCRM
    A::AbstractMatrix
    b::AbstractVector
    α::Number
end

function in(x₀::Vector, ell::EllipsoidCRM)
    A, b, α = ell.A, ell.b, ell.α
    if dot(x₀, A * x₀) + 2 * dot(b, x₀) ≤ α
        return true
    else
        return false
    end
end
"""
Transform Ellipsoid in format dot(x-c,Q⁻¹*(x-c)) ≤ 1 
into format  dot(x,A*x) + 2*dot(b,x) ≤ α
from shape matrix Q and center of ellipsoid c
"""
function EllipsoidCRM(c::Vector, Q::AbstractMatrix)
    A = inv(Matrix(Q))
    b = -A * c
    α = 1 + dot(c, b)
    return EllipsoidCRM(A, b, α)
end


"""
EllipsoidCRM(ell)

Transform Ellipsoid in format dot(x-c,Q⁻¹*(x-c)) ≤ 1 from LazySets
into format  dot(x,A*x) + 2*dot(b,x) ≤ α
from shape matrix Q and center of ellipsoid c
"""
EllipsoidCRM(ell::Ellipsoid) = EllipsoidCRM(ell.center, ell.shape_matrix)


"""
Ellipsoid(ell)
Transform Ellipsoid in format  dot(x,A*x) + 2*dot(b,x) ≤ α to format dot(x-c,Q⁻¹*(x-c)) ≤ 1 from LazySets
from shape matrix Q and center of ellipsoid c
"""
function Ellipsoid(ell::EllipsoidCRM)
    c = -(ell.A \ ell.b)
    β = ell.α - dot(c, ell.b)
    Q = Symmetric(inv(Matrix(ell.A) / β))
    return Ellipsoid(c, Q)
end



"""
Proj_Ellipsoid(x₀, ell)
Projects x₀ onto ell, and EllipsoidCRM using an ADMM algorithm as reported by Jia, Cai and Han [Jia2007]

[Jia2007] Z. Jia, X. Cai, e D. Han, “Comparison of several fast algorithms for projection onto an ellipsoid”, Journal of Computational and Applied Mathematics, vol. 319, p. 320–337, ago. 2017, doi: 10.1016/j.cam.2017.01.008.
"""
function Proj_Ellipsoid(x₀::Vector,
    ell::EllipsoidCRM;
    itmax::Int=10_000,
    ε::Real=1e-8)
    x₀ ∉ ell ? nothing : return x₀
    A, b, α = ell.A, ell.b, ell.α
    ϑₖ = 10 / norm(A)
    n = length(x₀)
    B = sqrt(Matrix(A))
    issymmetric(B) ? BT = B : BT = B'
    b̄ = B \ (-b)
    αplusb̄2 = α + norm(b̄)^2
    r = sqrt(αplusb̄2)
    yₖ = ones(n)
    λₖ = ones(n)
    xₖ = x₀
    it = 0
    tolADMM = 1.0
    function ProjY(y)
        normy = norm(y)
        if αplusb̄2 - normy^2 ≥ 0.0
            return y
        else
            return (r / normy) * y
        end
    end
    Ā = (I + ϑₖ * A)
    normRxₖ = 0.0
    while tolADMM ≥ ε^2 && it ≤ itmax
        uₖ = x₀ + BT * (λₖ + ϑₖ * (yₖ + b̄))
        xₖ = Ā \ uₖ
        wₖ = B * xₖ - λₖ ./ ϑₖ - b̄
        normwₖ = norm(wₖ)
        normwₖ ≤ r ? yₖ = wₖ : yₖ = (r / normwₖ) * wₖ
        Rxₖ = xₖ - x₀ - BT * λₖ
        Ryₖ = yₖ - ProjY(yₖ - λₖ)
        Rλₖ = B * xₖ - yₖ - b̄
        λₖ -= ϑₖ * Rλₖ
        normRxₖ = norm(Rxₖ)
        normRyₖ = norm(Ryₖ)
        normRλₖ = norm(Rλₖ)
        tolADMM = sum([normRxₖ^2, normRyₖ^2, normRλₖ^2])
        it += 1
        # if normRxₖ < normRλₖ*(0.1/n)
        #     ϑₖ *= 2
        # elseif normRxₖ > normRλₖ*(0.9/n)
        #     ϑₖ *= 0.5
        # end

    end

    # @show it, normRxₖ
    return real.(xₖ)
end

