module VectorSpaces

export VectorSpace, ZeroSpace, dim, span, span_adjoint, kernel, image, preimage
export rank

using LinearAlgebra

import Base: show, size, copy, adjoint, union, intersect, in, issubset, (==), (*), (\)
import Base: eltype
import LinearAlgebra: rank

struct VectorSpace{T<:Number,Q<:Union{QRPivoted{T},Nothing}}
    n::Int
    rank::Int
    first::Int
    qrf::Q
    VectorSpace{T}(n::Int, rank::Int, first::Int, qrf::Q) where {T,Q} =
        new{T,Q}(n, rank, first, qrf)
end

function show(io::IO, vs::VectorSpace)
    println(io, typeof(vs), " rank ", vs.rank, " dim ", vs.n)
end

"""
    VectorSpace(A::Union{AbstractMatrix,AbstractVector})

Create VectorSpace as subspace spanned by the column vectors of A.
The base space has dimension of the number of rows of A.
The dimension of the subspace is the (numerical) rank of A.
"""
function VectorSpace(A::AbstractMatrix{T}) where {T<:Number}
    n, m = size(A)
    r = 0
    if m > 0
        tol = tolerance(A)
        qrf = qr(A, ColumnNorm())
        r = _rank(qrf, tol)
    end
    if r <= 0 || r >= n
        qrf = nothing
    end
    VectorSpace{T}(n, r, 1, qrf)
end

VectorSpace(B::AbstractVector{T}) where {T<:Number} = VectorSpace(reshape(B, size(B, 1), 1))
"""
    ZeroSpace([T<:Number,] n) -> VectorSpace

Create zero space in base space of dimension `n`. Default type is Float64.
"""
ZeroSpace(::Type{T}, n::Int) where {T<:Number} = VectorSpace{T}(n, 0, 1, nothing)
ZeroSpace(n::Int) = ZeroSpace(Float64, n)

"""
    VectorSpace([T<:Number], n)

Create base space of dimension`n`. Default type is Float64.
"""
VectorSpace(::Type{T}, n::Int) where {T<:Number} = VectorSpace{T}(n, n, 1, nothing)
VectorSpace(n::Int) = VectorSpace(Float64, n)

size(vs::VectorSpace) = (vs.n, vs.rank)
rank(vs::VectorSpace) = vs.rank
dim(vs::VectorSpace) = vs.n
eltype(::VectorSpace{T}) where T = T

copy(vs::VectorSpace{T}) where {T} = VectorSpace{T}(vs.n, vs.rank, vs.first, vs.qrf)

"""
    adjoint(vs::VectorSpace) -> VectorSpace

Create VectorSpace representing the orthogonal complement of `vs`. May be written `vs'`.
"""
function adjoint(vs::VectorSpace{T}) where {T}
    n, r = size(vs)
    if vs.first == 1
        f = r + 1
    else
        f = 1
    end
    r = n - r
    VectorSpace{T}(n, r, f, vs.qrf)
end

"""
    span(vs::VectorSpace) -> Matrix

Return unitary matrix containing basis vectors of `vs`.
"""
function span(vs::VectorSpace{T}) where {T}
    if 0 < vs.rank < vs.n
        r = _range1(vs)
        vs.qrf.Q[:, r]
    else
        Matrix{T}(I, vs.n, vs.rank)
    end
end

"""
    span_adjoint(vs::VectorSpace) -> Matrix

Return unitary matrix containing basis vectors of orthogonal complement of `vs`.
Generally `span(vs') == span_adjoint(vs) is true`.
"""
function span_adjoint(vs::VectorSpace{T}) where {T}
    if 0 < vs.rank < vs.n
        r = _range2(vs)
        vs.qrf.Q[:, r]
    else
        Matrix{T}(I, vs.n, vs.n - vs.rank)
    end
end

@inline function _range1(vs::VectorSpace)
    f = vs.first
    l = vs.rank + f - 1
    f:l
end

@inline function _range2(vs::VectorSpace)
    n, r = size(vs)
    f = vs.first == 1 ? r + 1 : 1
    l = n - r + f - 1
    f:l
end

"""
    *(A::AbstractMatrix, vs::VectorSpace) -> VectorSpace

Calculate the image of the vector space `vs` under matrix `A`.
Discard small column vectors in `A * span(vs)`.
Use `A * vs` rather than `VectorSpace(A * span(A))` for accuracy.
"""
function *(A::AbstractMatrix{T}, vs::VectorSpace{T}) where {T<:Number}
    n, m = size(A)
    nv, r = size(vs)
    m == nv || error("dimension mismatch")

    if r == 0
        ZeroSpace(T, n)
    elseif r == nv
        VectorSpace(A)
    else
        spana = A * span(vs)
        tol = tolerance(A)
        for k = 1:r
            if norm(spana[:, k], Inf) < tol
                spana[:, k] .= 0
            end
        end
        VectorSpace(spana)
    end
end

"""
    \\(A::AbstractMatrix, vs::VectorSpace) -> VectorSpace

Calculate the preimage of the vector space `vs` under matrix `A`.
Discard small row vectors in `span(vs')' * A`.
Use `A \\ vs` rather than `VectorSpace(span(vs')'A)` for accuracy.
"""
function \(A::AbstractMatrix{T}, vs::VectorSpace{T}) where {T<:Number}
    n, m = size(A)
    nv, r = size(vs)
    n == nv || error("dimension mismatch")

    if r == nv
        VectorSpace(T, m)
    elseif r == 0
        kernel(A)
    else
        spana = span_adjoint(vs)'A
        tol = tolerance(A)
        for k = 1:nv-r
            if norm(spana[k, :], Inf) < tol
                spana[k, :] .= 0
            end
        end
        kernel(spana)
    end
end

"""
    image(A:AbstractMatrix[, vs::VectorSpace] [, k = 1]) -> VectorSpace

Create image of `vs` under `A^k`. If k ≠ 1 A must be square matrix.
If vs is not given, the usual image (range) of `A` is returned.
"""
image(A::AbstractArray{T}) where {T<:Number} = VectorSpace(A)
function image(A::AbstractArray{T}, k::Int) where {T<:Number}
    k == 1 ? VectorSpace(A) : image(A, VectorSpace(T, size(A, 2)), k)
end

function image(A::AbstractMatrix, vs::VectorSpace, k::Int = 1)
    k ≥ 0 || error("exponent ≥ 0 required")
    n, m = size(A)
    na, ra = size(vs)
    n == m || k == 1 || error("exponent k ≠ 1 only for square matrix")
    na == m || error("matrix dimension 2 does not match source space dimension")

    va = vs
    if k > 0
        va = ra == m ? image(A) : A * va
        for _ = 1:k-1
            r = rank(va)
            0 < r < m || break
            va = A * va
        end
    end
    va
end

"""
    kernel(A::AbstractArray) -> VectorSpace

Create VectorSpace representing the kernel or null-space of the mapping given by matrix `A`.
"""
kernel(A::AbstractArray) = VectorSpace(kernel_matrix(A))

"""
    preimage(A::AbstractArray[, vs::VectorSpace] [, k::Int=1])

Create vector space, which is the inverse image of `vs` under the mapping `A^k`.
`vs` defaults to the zero space; in that case the kernel of `A^k` is returned.
"""
preimage(A::AbstractArray{T}) where {T<:Number} = kernel(A)
function preimage(A::AbstractArray{T}, k::Int) where {T<:Number}
    k == 1 ? kernel(A) : preimage(A, ZeroSpace(T, size(A, 1)), k)
end

function preimage(A::AbstractArray, vs::VectorSpace, k::Int = 1)
    k ≥ 0 || error("exponent ≥ 0 required")
    n, m = size(A)
    na, ra = size(vs)
    n == m || k == 1 || error("exponent k ≠ 1 only for square matrix")
    na == n || error("matrix dimension 1 does not match target space dimension")

    va = vs
    if k > 0
        va = ra == 0 ? kernel(A) : A \ va
        for _ = 1:k-1
            r = rank(va)
            0 < r < n || break
            va = A \ va
        end
    end
    va
end

"""
    union(va::VectorSpace, vb::VectorSpace) -> VectorSpace

Create VectorSpace representing `va ∪ vb`. VectorSpace
"""
function union(va::VectorSpace, vb::VectorSpace)
    na, ra = size(va)
    nb, rb = size(vb)
    na == nb || error("dimension mismatch")

    if ra >= na || rb >= nb
        VectorSpace(eltype(va), na)
    elseif ra == 0
        vb
    elseif rb == 0
        va
    else
        A = [span(va) span(vb)]
        VectorSpace(A)
    end
end

"""
    intersect(va::VectorSpace, vb::VectorSpace) -> VectorSpace

Create VectorSpace representing `va ∩ vb`.
"""
function intersect(va::VectorSpace, vb::VectorSpace)
    na, ra = size(va)
    nb, rb = size(vb)
    na == nb || error("dimension mismatch")

    if ra == 0 || rb == 0
        ZeroSpace(eltype(va), na)
    elseif ra == na
        vb
    elseif rb == nb
        va
    else
        U = span(va)
        V = span(vb)
        K = kernel_matrix([U -V])
        VectorSpace(U * K[1:rank(va), :])
    end
end

"""
    in(A::AbstractArray, vb::VectorSpace) -> Bool

Determine if `A[:,k] ∈ vb ∀ k`.
"""
function Base.in(A::AbstractArray, vs::VectorSpace)
    issubset(VectorSpace(A), vs)
end

"""
    issubset(va::VectorSpace, vb::VectorSpace) -> Bool

Determine if `va ⊆ vb`.
"""
function Base.issubset(va::VectorSpace{T}, vb::VectorSpace{T}) where {T<:Number}
    na, ra = size(va)
    nb, rb = size(vb)
    na == nb || error("vector spaces not in same base space")

    rb >= nb || ra <= 0 && return true
    ra > rb && return false
    spanba = span_adjoint(vb)' * span(va)
    norm(vec(spanba), Inf) <= 4eps(T) * na
end

"""

    va == vb

Determine if VectorSpaces are (numerically) equal.
Equivalent to `va ⊆ vb and vb ⊆ va`.
"""
function ==(va::VectorSpace, vb::VectorSpace)
    va.rank == vb.rank && issubset(va, vb)
end

#########################################################################################

function _rank(
    QR::LinearAlgebra.QRPivoted{T,S},
    tol::AbstractFloat,
) where {S<:AbstractMatrix{T}} where {T<:Number}
    minimum(size(QR)) == 0 && (return 0)
    R = QR.R
    sv = sort(abs.(diag(R)); rev = true)
    n = length(sv)
    while n > 0 && sv[n] <= tol
        n -= 1
    end
    n
end

"""
    tolerance(A::AbstractMatrix)

Return standard tolerance for a matrix.
"""
@inline tolerance(A::AbstractMatrix) = eps(norm(A, 1)) * maximum(size(A))

"""
    kernel_matrix(A::AbstractMatrix) -> Matrix

Produce unitary matrix, whose vectors are basis of the kernel of Matrix A.
If the matrix is injective, the a matrix with zero columns is returned.
If the matrix has rank zero, the unit matrix is returned.
"""
function kernel_matrix(A::AbstractMatrix{T}) where {T<:Number}

    tol = tolerance(A)
    QR = qr(A, ColumnNorm())
    r = _rank(QR, tol)
    n, m = size(A)
    K = zeros(T, m, m - r)
    for k = r+1:m
        K[k, k-r] = one(T)
    end
    if 0 < r < m
        r1r = 1:r
        rrm = r+1:m
        R = QR.R
        RV = view(R, r1r, r1r)
        K[r1r, :] = -RV \ R[r1r, rrm]
        p = invperm(QR.p)
        K = Matrix(qr(K[p, :]).Q)
    end
    K
end

function kernel_matrix(A::AbstractVector{T}) where {T<:Number}
    kernel_matrix(reshape(A, size(A, 1), 1))
end

end # module
