# PortableGameNotation.jl
Julia language tools for processing portable game notation (PGN) files

[![Build
Status](https://travis-ci.org/davidssmith/PortableGameNotation.jl.svg?branch=master)](https://travis-ci.org/davidssmith/PortableGameNotation.jl)
[![Build
status](https://ci.appveyor.com/api/projects/status/6qxhv02o4k8jgp21?svg=true)](https://ci.appveyor.com/project/davidssmith/portablegamenotation-jl)
[![Coverage
Status](https://coveralls.io/repos/github/davidssmith/PortableGameNotation.jl/badge.svg?branch=master)](https://coveralls.io/github/davidssmith/PortableGameNotation.jl?branch=master)

## Example Usage

```
julia> using PortableGameNotation

julia> g = readpgn(Pkg.dir("PortableGameNotation","test/test.pgn"));

julia> white(g[1])
"Adolf Anderssen"

julia> black(g[1])
"Jean Dufresne"

julia> result(g[1])
"1-0"

