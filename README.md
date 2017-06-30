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
"Wei Yi"

julia> black(g[1])
"Lazaro Bruzon Batista"

julia> result(g[1])
"1-0"

julia> println(g[1])
[Event "6th Hainan Danzhou"]
[Site "Danzhou CHN"]
[Date "2015.07.03"]
[Round "2.4"]
[White "Wei Yi"]
[Black "Lazaro Bruzon Batista"]
[Result "1-0"]
[EventDate "2015.07.02"]
[ECO "B40"]
[BlackElo "2669"]
[PlyCount "71"]
[WhiteElo "2724"]

1. e4 c5 2. Nf3 e6 3. Nc3 a6 4. Be2 Nc6 5. d4 cxd4 6. Nxd4 Qc7 7. O-O Nf6 8. Be3
Be7 9. f4 d6 10. Kh1 O-O 11. Qe1 Nxd4 12. Bxd4 b5 13. Qg3 Bb7 14. a3 Rad8 15.  Rae1
Rd7 16. Bd3 Qd8 17. Qh3 g6 18. f5 e5 19. Be3 Re8 20. fxg6 hxg6 21. Nd5 Nxd5 22.
Rxf7 Kxf7 23. Qh7+ Ke6 24. exd5+ Kxd5 25. Be4+ Kxe4 26. Qf7 Bf6 27. Bd2+ Kd4 28.
Be3+ Ke4 29. Qb3 Kf5 30. Rf1+ Kg4 31. Qd3 Bxg2+ 32. Kxg2 Qa8+ 33. Kg1 Bg5 34.  Qe2+
Kh4 35. Bf2+ Kh3 36. Be1 1-0
