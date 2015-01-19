#################################################################
# Randomized estimators of elementary linear algebraic quantities
#################################################################

export rcond, reigmax, reigmin, rnorm, rnorms



"""
Randomized Gaussian matrices normalized by column

Input:
    el: element type
    m: number of rows
    n: number of columns or nothing
    normalize: whether or not to normalize (default:true)
"""
function randnn(el, m::Int, normalize::Bool=true)
    if el <: Real
        Ω = randn(m)
    elseif el <: Complex
        Ω = randn(m) + im*randn(m)
    else
        throw(ValueError("Unsupported element type: $el"))
    end
    normalize ? Ω/norm(Ω) : Ω
end
function randnn(el, m::Int, n::Int, normalize::Bool=true)
    if el <: Real
        Ω = randn(m, n)
    elseif el <: Complex
        Ω = randn(m, n) + im*randn(m, n)
    else
        throw(ValueError("Unsupported element type: $el"))
    end
    normalize || return Ω
    for i=1:n
        Ω[:, i] /= norm(sub(Ω, :, i))
    end
    Ω
end



"""
Randomized matrix norm estimator

Computes a probabilistic upper bound on the norm of a matrix A.

Lemma 4.1 of (Halko, 2011) states (with slight notational change)
that

‖A‖ ≤ α √(2/π) maxᵢ ‖Aωᵢ‖

with probability p=α^(-r).

Inputs:
    A: Matrix whose norm to estimate
    r: Number of matrix-vector products to compute
    p: Probability of upper bound failing (default: 0.05)

Output:
    Estimate of ‖A‖.

Comment:
    see rnorms() for a different estimator that uses
    premultiplying by both A and A'
"""
function rnorm(A, r::Int, p::Real=0.05)
    @assert 0<p≤1
    α = p^(-1.0/r)
    m, n = size(A)
    Ω = randnn(eltype(A), n, r, false)
    AΩ = A*Ω
    mx = maximum([norm(sub(AΩ, :, j)) for j=1:r])
    α * √(2/π) * mx
end



"""
Randomized matrix norm estimator using A'A

Computes a probabilistic upper bound on the norm of a matrix A.

The Reference states (with minor change in notation) that 

ρ = √(‖(A'A)ʲω‖/‖(A'A)ʲ⁻¹ω‖)

which is an estimate of the spectral norm of A produced by j
steps of the power method starting with normalized ω, is a lower
bound on the true norm by a factor

ρ ≤ α ‖A‖

with probability greater than 1 - p, p = 4√(n/(j-1))*α^(-2j).

Inputs:
    A: Matrix whose norm to estimate
    j: Number of power iterations to perform (default: 1)
    p: Probability of upper bound failing (default: 0.05)
    At (optional keyword): Transpose of A. Default: A'

Output:
    Estimate of ‖A‖.

Reference:
    Edo Liberty, Franco Woolfe, Per-Gunnar Martinsson, Vladimir Rokhlin and Mark Tygert,
    "Randomized algorithms for the low-rank approximation of matrices",
    Proceedings of the National Academy of Sciences, 104 (51), 2007, 20167-20172,
    doi:10.1073/pnas.0709640104
    Appendix

Comment:
    see rnorm() for a different estimator that does not require
    premultiplying by A'
"""
function rnorms(A, j::Int=1, p::Real=0.05; At = A')
    @assert 0<p≤1
     m, n = size(A)
    α = ((j-1)/n*(p/4)^2)^(-1/(4j))

    Ωold = Ω = randnn(eltype(A), n)
    for i=1:j #Power iterations
        Ω, Ωold = At*(A*Ω), Ω
    end
    ρ = √(norm(Ω)/norm(Ωold))
    α*ρ
end



"""
Randomized condition number estimator

Inputs:
    A: Matrix whose condition number to estimate.
       Must be square and support premultiply (A*⋅) and solve (A\⋅)
    k: Number of power iterations to run. Default: 1 (Recommended: k ≤ 3)
    p: Probability that estimate fails to hold as an upper bound
       (Default: 0.05)

Output:
    The interval (x, y) which contains κ(A) with probability 1-p.

Implementation note:
    The reference originally describes this as a computation that can be done
    by computing the necessary number of power iterations given p and the
    desired accuracy parameter θ=y/x. However, these bounds were only derived
    under the assumptions of exact arithmetic. Empirically, k≥4 has been seen
    to result in incorrect results in that the computed interval does not
    contain the true condition number. This implemention therefore makes k an
    explicitly user-controllable parameter.

Reference:
    Theorem 2 of
    @article{Dixon1983,
        author = {Dixon, John D},
        doi = {10.1137/0720053},
        journal = {SIAM Journal on Numerical Analysis},
        number = {4},
        pages = {812--814},
	title = {Estimating Extremal Eigenvalues and Condition Numbers of
		Matrices},
	volume = {20},
        year = {1983}
    }
"""
function rcond(A, k::Int=1, p::Real=0.05)
    @assert 0<p≤1
    m, n = size(A)
    @assert m==n
    θ = (8n/(π*p^2))^(1/k)
    x = randnn(eltype(A), n)
    for i=1:k
        x = A*x
    end
    y = randnn(eltype(A), n)
    for i=1:k
        y = A\y
    end
    φ = ((x⋅x)*(y⋅y))^(1/(2k))
    (φ, θ*φ)
end



"""
Randomized maximal eigenvalue estimator

Inputs:
    A: Matrix whose maximal eigenvalue to estimate.
       Must be square and support premultiply (A*⋅)
    k: Number of power iterations to run. Default: 1 (Recommended: k ≤ 3)
    p: Probability that estimate fails to hold as an upper bound
       (Default: 0.05)

Output:
    The interval (x, y) which contains the maximal eigenvalue of A with
    probability 1-p.

Reference:
    Corollary of Theorem 1 of Dixon1983.
"""
function reigmax(A, k::Int=1, p::Real=0.05)
    @assert 0<p≤1
    m, n = size(A)
    @assert m==n
    θ = (2n/(π*p^2))^(1/k)
    y = x = randnn(eltype(A), n)
    for i=1:k
        x = A*x
    end
    φ = y⋅x
    (φ, θ*φ)
end



"""
Randomized minimal eigenvalue estimator

Inputs:
    A: Matrix whose minimal eigenvalue to estimate.
       Must be square and support backslash (A\⋅)
    k: Number of power iterations to run. Default: 1 (Recommended: k ≤ 3)
    p: Probability that estimate fails to hold as an upper bound
       (Default: 0.05)

Output:
    The interval (x, y) which contains the minimal eigenvalue of A with
    probability 1-p.

Reference:
    Corollary of Theorem 1 of Dixon1983.
"""
function reigmin(A, k::Int=1, p::Real=0.05)
    @assert 0<p≤1
    m, n = size(A)
    @assert m==n
    θ = (2n/(π*p^2))^(1/k)
    y = x = randnn(eltype(A), n)
    for i=1:k
        x = A\x
    end
    φ = y⋅x
    (inv(θ*φ), inv(φ))
end



