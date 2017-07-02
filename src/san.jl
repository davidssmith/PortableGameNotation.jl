#} functions for parsing Standard Algebraic Notation (SAN) and converting
# movetext to a array of Move objects

import Base: start, done, next

# Examples:
# e4 exd4 d8=Q d8=Q+ d8=Q#
# Ne4 Nfe4 Nxe4 Nfxe4 Nxe4+ Nxe4# Nfxe4+ Nfxe4#
# O-O O-O-O O-O-O+ O-O+ O-O#  O-O-O#

PIECE_CODES = Dict("P"=>1, "N"=>2, "B" =>3, "R" =>4, "Q"=>5, "K"=>6, "O-O"=>7, "O-O-O"=>8)

UTF8_PIECE_SYMBOLS = Dict(
    'K' => '♔', 'Q' => '♕', 'R' => '♖', 'B' => '♗', 'N' => '♘', 'P' => '♙',
    'k' => '♚', 'q' => '♛', 'r' => '♜', 'b' => '♝', 'n' => '♞', 'p' => '♟')

COLOR_WHITE = true
COLOR_BLACK = false

type Move
  # bitfield: [ color | piece piece piece | iscap | ispromotion | iscastle | ischeck | ismate]
  color::Bool
  capture::Bool
  check::Bool
  mate::Bool
  piece::Int8
  promotion::Int8  # piece code of promotion, or 0 if not
  fromsquare::Int8
  tosquare::Int8
  #comment::String
end


MoveList = Array{Move,1}
MoveText = String

function square2subs(square::String)
  file = Int(square[1]) - Int('a') + 1
  rank = Int(square[2]) - Int('1') + 1
  (rank, file)
end
function index(square::String)
  # linear index of a square given in algebraic notation
  rank, file = square2subs(square)
  8*file + rank
end

capture(m::SubString) = 'x' in m
capture(m::Move) = m.capture
promotion(m::String) = '=' in m
promotion(m::Move) = m.ispromotion
check(m::String) = '+' in m
check(m::Move) = m.ischeck
mate(m::String) = '#' in m
mate(m::Move) = m.ismate

function chompspecial!(m::SubString, c::Char)
  if m[end] == c
    m = m[1:end-1]
    return true
  else
    return false
  end
end

function chomppiece!(m::SubString)
  if m[1] == 'O'
    if length(m) >= 4 && m[4] == '-'
      m = m[6:end]
      return PIECE_CODES["O-O-O"]
    else
      m = m[4:end]
      return PIECE_CODES["O-O"]
    end
  elseif isupper(m[1])
    p = m[1]
    m = m[2:end]
    return PIECE_CODES[string(p)]
  else
    return PIECE_CODES["P"]
  end
end

function chomppromotion!(m::SubString)
  # assumes no check or mate at end anymore
  if m[end-1] == '='
    c = PIECE_CODES[m[end]]
    m = m[1:end-2]
    return c
  else
    return 0
  end
end

"""
tosquare(s)

Parse string `s` and return the destination square.
"""
function tosquare(m::String)

end

"""
fromsquare(s)

Parse string `s` and return the origin square.
"""
function fromsquare(m::String)

end

function parse(movetext::String)
  moves = Array{Move}(1)
  col = COLOR_WHITE
  for m in split(movetext)
    code= chomppiece!(m)
    ma = chompspecial!(m, '#')
    ch = chompspecial!(m, '#')
    prom = chomppromotion!(m)
    cap = capture(m)
    to = 1
    fr = 1
    push!(moves, Move(col,cap,ch,ma,code,prom,to,fr))
    col = !col
  end
  return moves
end

println(parse("d4 Nf6 c4 g6"))
