# VectorSpaces

This package supports Standard vector spaces over `Number`.

## Usage

```julia

(...) pkg> add VectorSpaces

```

```jldoctest
julia> using VectorSpaces

julia> F = rand(26, 5);

julia> VF = image(F)
VectorSpace{Float64, Matrix{Float64}} rank 5 dim 26

julia> G = F[:,3:4];

julia> G = [G ones(26)];

julia> VG = image(G)
VectorSpace{Float64, Matrix{Float64}} rank 3 dim 26

julia> VF ∩ VG
VectorSpace{Float64, Matrix{Float64}} rank 2 dim 26

julia> VF ∪ VG
VectorSpace{Float64, Matrix{Float64}} rank 6 dim 26

span(VF ∩ VG)
26×2 Matrix{Float64}:
    ...

julia> kernel(F')
VectorSpace{Float64, Matrix{Float64}} rank 21 dim 26

julia> kernel(F') == image(F)'
true
 
julia> H = [G G[:,1]+G[:,2]];

julia> rank(H) == rank(image(H))
true

julia> kernel(H)' == image(H')
true
```
