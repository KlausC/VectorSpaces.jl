module TestVectorSpaces

using Test
using VectorSpaces
using Random

Random.seed!(1)

l, n, m = 2, 6, 4
A = randn(n, m)
B = randn(l, n)
M = randn(n, n)

Vn = VectorSpace(n)
Zn = ZeroSpace(n)

vz = ZeroSpace(n)
@test rank(vz) == 0 && dim(vz) == n

vf = VectorSpace(n)
@test rank(vf) == n && dim(vf) == n

va = VectorSpace(A)
@test rank(va) == min(m, n) && dim(va) == n
vb = VectorSpace(B)
@test rank(vb) == min(l, n) && dim(vb) == l

@test va == image(A)
@test vb == image(B)
@test A ∈ image(A)

@test va'' == va

@test vz ⊆ va ⊆ vf
@test va ∪ va == va
@test va ∪ va' == VectorSpace(eltype(va), dim(va))
@test va ∩ va == va
@test va ∩ va' == ZeroSpace(eltype(va), dim(va))

@test Vn ∩ va == va
@test Zn ∩ va == Zn
@test Vn ∪ va == Vn
@test Zn ∪ va == va
@test va ∩ Vn == va
@test va ∩ Zn == Zn
@test va ∪ Vn == Vn
@test va ∪ Zn == va

@test kernel(A) == ZeroSpace(m)
@test image(B) == VectorSpace(l)

@test kernel(A) == preimage(A)

@test kernel(A') == image(A)'
@test kernel(A)' == image(A')

@test A * VectorSpace(size(A, 2)) == image(A)
@test A \ ZeroSpace(n) == kernel(A)

@test preimage(M, va) == M \ va
@test preimage(M, va, 2) == (M^2) \ va
@test preimage(M, 2) == preimage(M, Zn, 2)

@test image(M, va) == M * va
@test image(M, va, 2) == M * M * va
@test image(M, 2) == image(M, Vn, 2)

@test image(M, Zn) == Zn
@test image(M, Vn) == image(M)
@test preimage(M, Vn) == Vn
@test preimage(M, Zn) == kernel(M)

@test kernel(ones(n)) == ZeroSpace(1)

end # module
