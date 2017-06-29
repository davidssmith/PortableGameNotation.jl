using Base.Test

include("../src/PortableGameNotation.jl")
using PortableGameNotation

g = readpgn("test.pgn")

print("TESTING on test.pgn ... ")

@test date(g[1]) == Date(2015,7,3)
@test site(g[1]) == "Danzhou CHN"
@test event(g[1]) == "6th Hainan Danzhou"
@test result(g[1]) == "1-0"
@test intresult(g[1]) == 1
@test white(g[1]) == "Wei Yi"
@test black(g[1]) == "Lazaro Bruzon Batista"
@test whiteelo(g[1]) == 2724
@test blackelo(g[1]) == 2669
@test eco(g[1]) == "B40"
@test eventdate(g[1]) == Date(2015,7,2)
@test plycount(g[1]) == 71
@test movetext(g[1]) == """1. e4 c5 2. Nf3 e6 3. Nc3 a6 4. Be2 Nc6 5. d4 cxd4 6. Nxd4 Qc7 7. O-O Nf6 8. Be3 Be7 9. f4 d6 10. Kh1 O-O 11. Qe1 Nxd4 12. Bxd4 b5 13. Qg3 Bb7 14. a3 Rad8 15. Rae1 Rd7 16. Bd3 Qd8 17. Qh3 g6 18. f5 e5 19. Be3 Re8 20. fxg6 hxg6 21. Nd5 Nxd5 22. Rxf7 Kxf7 23. Qh7+ Ke6 24. exd5+ Kxd5 25. Be4+ Kxe4 26. Qf7 Bf6 27. Bd2+ Kd4 28. Be3+ Ke4 29. Qb3 Kf5 30. Rf1+ Kg4 31. Qd3 Bxg2+ 32. Kxg2 Qa8+ 33. Kg1 Bg5 34. Qe2+ Kh4 35. Bf2+ Kh3 36. Be1 1-0"""
@test length(g[1]) == 36
@test whiteev(g[1]) == 0.5784967523447427
@test blackev(g[1]) == 0.42150324765525726
@test whitescore(g[1]) == 1
@test blackscore(g[1]) == 0
@test whiteperfelo(g[1]) == 3069
@test blackperfelo(g[1]) == 2324
@test isdecisive(g[1]) == true

@test PortableGameNotation.validate(g[1])


@test date(g[2]) == Date(2016,4,29)
@test site(g[2]) == "St. Louis, MO USA"
@test event(g[2]) == "Ultimate Blitz Challenge"
@test result(g[2]) == "1-0"
@test intresult(g[2]) == 1
@test white(g[2]) == "Wesley So"
@test black(g[2]) == "Garry Kasparov"
@test whiteelo(g[2]) == 2773
@test blackelo(g[2]) == 2812
@test eventdate(g[2]) == Date(2016,4,28)
@test eco(g[2]) == "A41"
@test plycount(g[2]) == 49
@test movetext(g[2]) == """1. Nf3 g6 2. e4 Bg7 3. d4 d6 4. c4 Bg4 5. Be2 Nc6 6. Nbd2 e5 7. d5 Nce7 8. h3 Bd7 9. c5 dxc5 10. Nc4 f6 11. d6 Nc8 12. Be3 b6 13. O-O Bc6 14. dxc7 Qxc7 15. b4 cxb4 16. Rc1 Nge7 17. Qb3 h6 18. Rfd1 b5 19. Ncxe5 fxe5 20. Bxb5 Rb8 21. Ba4 Qb7 22. Rxc6 Nxc6 23. Qe6+ Ne7 24. Bc5 Rc8 25. Bxe7 1-0"""
@test length(g[2]) == 25
@test whiteev(g[2]) == 0.4441090388831469
@test blackev(g[2]) == 0.5558909611168531
@test whitescore(g[2]) == 1
@test blackscore(g[2]) == 0
@test whiteperfelo(g[2]) == 3212
@test blackperfelo(g[2]) == 2373
@test isdecisive(g[2]) == true
@test PortableGameNotation.validate(g[2])

println("PASSED")
