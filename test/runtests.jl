using Base.Test

include("../src/PortableGameNotation.jl")
using PortableGameNotation

g = readpgn("test.pgn")

print("TESTING on test.pgn ... ")

@test date(g[1]) == "1852.??.??"
@test site(g[1]) == "Berlin GER"
@test event(g[1]) == "Berlin GER"
@test result(g[1]) == "1-0"
@test white(g[1]) == "Adolf Anderssen"
@test black(g[1]) == "Jean Dufresne"
@test whiteelo(g[1]) == "?"
@test blackelo(g[1]) == "?"
@test eco(g[1]) == "C52"
@test eventdate(g[1]) == "?"
@test plycount(g[1]) == "47"
@test movetext(g[1]) == """
1.e4 e5 2.Nf3 Nc6 3.Bc4 Bc5 4.b4 { Evans Gambit } Bxb4 5.c3 Ba5 6.d4 exd4 7.O-O d3 8.Qb3 Qf6 9.e5 Qg6 10.Re1 Nge7 11.Ba3 b5 12.Qxb5 Rb8 13.Qa4 Bb6 14.Nbd2 Bb7 15.Ne4 Qf5 16.Bxd3 Qh5 17.Nf6+ gxf6 18.exf6 Rg8 19.Rad1 Qxf3 20.Rxe7+ Nxe7 21.Qxd7+ Kxd7 22.Bf5+ Ke8 23.Bd7+ Kf8 24.Bxe7# 1-0"""
#@test length(g[1]) == 24
@test PortableGameNotation.validate(g[1])


@test date(g[2]) == "1851.06.21"
@test site(g[2]) == "London ENG"
@test event(g[2]) == "London"
@test result(g[2]) == "1-0"
@test white(g[2]) == "Adolf Anderssen"
@test black(g[2]) == "Lionel Adalbert Bagration Felix Kieseritzky"
@test whiteelo(g[2]) == "?"
@test blackelo(g[2]) == "?"
@test eventdate(g[2]) == "?"
@test eco(g[2]) == "C33"
@test plycount(g[2]) == "45"
@test movetext(g[2]) == """
1.e4 e5 2.f4 { King's Gambit } exf4 3.Bc4 Qh4+ 4.Kf1 b5 5.Bxb5 Nf6 6.Nf3 Qh6 7.d3 Nh5 8.Nh4 Qg5 9.Nf5 c6 10.g4 Nf6 11.Rg1 cxb5 12.h4 Qg6 13.h5 Qg5 14.Qf3 Ng8 15.Bxf4 Qf6 16.Nc3 Bc5 17.Nd5 Qxb2 18.Bd6 Bxg1 {It is from this move that Black's defeat stems. Wilhelm Steinitz suggested in 1879 that a better move would be 18... Qxa1+; likely moves to follow are 19. Ke2 Qb2 20. Kd2 Bxg1.} 19. e5 Qxa1+ 20. Ke2 Na6 21.Nxg7+ Kd8 22.Qf6+ Nxf6 23.Be7# 1-0"""
#@test length(g[2]) == 23
@test PortableGameNotation.validate(g[2])

println("PASSED")
