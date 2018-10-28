
module PortableGameNotation

import Base.show, Base.length, Base.println

using Dates
using Printf

export readpgn, writepgn, Game, event, site, date, round, white, black, result,
  whiteelo, blackelo, eventdate, eco, movetext, plycount, length, movestring,
  headerstring, repr, intresult, whiteev, blackev, whitescore, blackscore,
  whiteperfelo, blackperfelo, isdecisive

mutable struct Move
  san::String
  #nag::UInt8
  comment::String
end
mutable struct Game
  header::Dict{String, String}
  moves::Array{Move,1}
end

RESULT_HASH = Dict{String,Int}("1-0" => 1, "1/2-1/2" => 0, "0-1" => -1, "*" => 0)
REQUIRED_TAGS = ["Event", "Site", "Date", "Round", "White", "Black", "Result"]
DEFAULT_HASH = Dict("Event"=>"","Site"=>"","Date"=>"","Round"=>"","White"=>"",
  "Black"=>"","Result"=>"")

const SIDE_WHITE = 0
const SIDE_BLACK = 1

const SUPER_STATE_HEADER = 0
const SUPER_STATE_MOVES = 1

const STATE_UNKNOWN = 0
const STATE_MOVE_NUMBER = 1  # currently reading a move number
const STATE_MOVE = 2         # currently reading a move
const STATE_COMMENT = 3      # currently reading a comment
const STATE_NAG = 4          # numeric annotation glyph
const STATE_RESULT = 5

statetext = Dict{Int,String}()
statetext[0] = "unknown"
statetext[1] = "hdrtag"
statetext[2] = "hdrval"
statetext[3] = "move#"
statetext[4] = "move"
statetext[5] = "comment"
statetext[6] = "period"
statetext[7] = "space"
statetext[8] = "NAG"



"""
readpgn(filename; [skim=false, verbose=false])

Read games from PGN file `filename` and returns an array of `Game`
objects.

If `skim` is set to true, movetexts will be ignored, making the read
process faser and less memory intensive for cases when only header
information is required.
"""
function readpgn(pgnfilename::String; verbose=true, skim=false, prealloc=true)
  # This is an alternative constructor that performs a state-based
  # single scan of the move text to parse into Move objects, hopefully
  # as quickly and efficiently as possible
  # skim=true will skip move parsing and just return a Game object
  # with headers as quickly as possible for cases in which you don't
  # care about the moves
  # TODO:
  #   - deal with precomments
  #   - deal with NAGS
  #   - deal with ; comments
  #   - implement skim
  # COMMENTS
  # Comments are inserted by either a ; (a comment that continues
  # to the end of the line) or a { (which continues until a matching }).
  # Comments do not nest.
  f = open(pgnfilename,"r")
  lines = readlines(f)
  close(f)
  if prealloc
    games = Vector{Game}(undef, div(filesize(pgnfilename), 500)) # guess
  else
    games = Vector{Game}()
  end
  ngamesread = 0
  newgame = false
  current_header = Dict{String,String}()
  current_movetext = ""
  for l in lines
    if length(l) == 0
      println("BETWEEN> ", l)
      if length(current_movetext) > 0 && length(current_header) > 0 # finished a game
        moves = parse_movetext(current_movetext)
        g = Game(current_header, moves)
        ngamesread += 1
        println("PUSHING> ", g)
        if ngamesread <= length(games)
          games[ngamesread] = g
        else
          push!(games, g)
        end
        newgame = true
      end
    elseif l[1] == '['
      k, v = parse_header_line(l)
      println("HEADER> ", (k,v))
      current_header[k] = v
    else
      current_movetext *= l
      #println("MOVETEXT> ", l)
    end
    if newgame
      current_movetext = ""
      current_header = Dict{String,String}()
      newgame = false
    end
  end
  return games[ngamesread]
end


function parse_header_line(line::String)
  # parse a PGN header line and return a (key,val) tuple
  k1 = findfirst("[", line)[1] + 1
  k2 = findnext(" ", line, k1)[1] - 1
  v1 = findnext("\"", line, k2)[1] + 1
  v2 = findnext("\"", line, v1)[1] - 1
  return (line[k1:k2], line[v1:v2])
end

function parse_movetext(S::String)
  # parse a line of movetext
  # assumes <= 100 moves per line
  moves = Move[]
  state = STATE_UNKNOWN
  current_move = ""
  current_comment = ""
  k = 1
  while k < length(S)
    if state == STATE_UNKNOWN
      if isdigit(S[k])
        state = STATE_MOVE_NUMBER
      elseif S[k] == '{'
        state = STATE_COMMENT
      elseif S[k] != ' '
        state = STATE_MOVE
      else  # skip everything else
        k += 1
      end
    elseif state == STATE_MOVE_NUMBER
      k += 1
      while true
        if isdigit(S[k]) || S[k] == '.'
          k += 1
        elseif S[k] == '-' || S[k] == '/'
          state = STATE_RESULT
          break
        else
          state = STATE_MOVE  # replace with ischar?
          break
        end
        if k > length(S)
          state = STATE_RESULT
          break
        end
      end
    elseif state == STATE_COMMENT
      k += 1
      comment_depth = 1
      startidx = k
      while comment_depth > 0
        if S[k] == '{'
          comment_depth += 1
        elseif S[k] == '}'
          comment_depth -= 1
        end
        k += 1
      end
      current_comment = S[startidx:k-2]
      state = STATE_UNKNOWN
    elseif state == STATE_MOVE
      if current_move != ""
        push!(moves, Move(current_move, current_comment))
        current_comment = ""
      end
      startidx = k
      while true
        if S[k] == ' '
          current_move = S[startidx:k-1]
          break
        elseif k >= length(S)
          current_move = S[startidx:k]
          break
        else
          k += 1
        end
      end
      state = STATE_UNKNOWN
    elseif state == STATE_NAG
      @info "NAG NOT IMPLEMENTED YET"
    elseif state == STATE_RESULT
      break
    else
      @info "UNHANDLED STATE" state S k moves
    end
  end
  if current_move != ""
    push!(moves, Move(current_move, current_comment))
  end
  return moves
end


"""
headerstring(g)

Format the headers of game `g` according to the PGN specification.
"""
function headerstring(g::Game)
  s = String[]
  # tags required by standard must be printed first and in order
  for t in REQUIRED_TAGS
    push!(s, "[$t \"$(g.header[t])\"]\n")
  end
  for k in keys(g.header)
    if !(k in REQUIRED_TAGS)
      push!(s, "[$k \"$(g.header[k])\"]\n")
    end
  end
  join(s, "")
end

"""
movestring(g)

Format the move text of game `g` with wrapping and linebreaks.
"""
function movestring(g::Game; line=80, comments=true)
  output = String[]
  linelen = 0
  ply = 0
  for m in g.moves
    if ply % 2 == 0
      str ="$(div(ply,2)+1)."
      linelen += length(str)
      if linelen >= line
        push!(output, "\n")
        linelen = length(str)
      end
      push!(output, str)
    end
    linelen += length(m.san) + 1
    if linelen >= line
        push!(output, "\n")
        linelen = length(m.san) + 1
    end
    push!(output, "$(m.san) ") # TODO: avoid string interp?
    if comments && m.comment != ""
      linelen += length(m.comment) + 1
      if linelen >= line
        push!(output, "\n")
        linelen = length(m.comment) + 1
      else
        push!(output, " ")
      # TODO: wrap comments
      end
      push!(output, "{$(m.comment)} ")
    end
    ply += 1
  end
  join(output, "")
end


resultstring(g::Game) = g.header["Result"]

function Base.repr(mime, m::Move)
  if m.side == SIDE_WHITE && m.comment == ""
    return "$(m.number)."*m.san
  elseif m.side == SIDE_WHITE && m.comment != ""
    return "$(M.number)."*m.san*" "*m.comment
  elseif m.comment == ""
    return m.san
  else
    return m.san*" "*m.comment
  end
end
function Base.show(io::IO, g::Game)
  println(io, white(g), " - ", black(g), ", ", site(g), " ", Dates.year(date(g)))
end
function Base.println(g::Game)
    Base.println(headerstring(g))
    Base.print(movestring(g), " ")
    Base.println(resultstring(g), "\n")
end

plycount(g::Game) = length(g.moves)
"""
length(g)

Number of moves in the game `g`.
"""
length(g::Game) = div(plycount(g), 2) + 1

function validate(g::Game)
  for t in REQUIRED_TAGS
    if !(t in keys(g.header))
      return false
    end
  end
  return true
end

function query(g::Game, key::String, default="?")
  try
    return g.header[key]
  catch KeyError
    return default
  end
end

function intquery(g::Game, key::String, default=0)
  s = query(g, key)
  try
    t = parse(Int, s)
  catch ArgumentError
    return default
  end
end

function datequery(g::Game, key::String)
  y, m, d = split(query(g, key),'.')
  if occursin("?", y)
    return Dates.Date(1970,1,1)
  elseif occursin("?", m)
    return Dates.Date(parse(Int,y))
  elseif occursin("?", d)
    return Dates.Date(parse(Int,y), parse(Int,m))
  else
    return Dates.Date(parse(Int,y), parse(Int,m), parse(Int,d))
  end
end

"""
white(g)

Name of white player in game `g`
"""
white(g::Game) = query(g, "White")
"""
black(g)

Name of black player in game `g`
"""
black(g::Game) = query(g, "Black")
"""
date(g)

Date game `g` was played.
"""
date(g::Game) = datequery(g, "Date")
"""
site(g)

Location where game `g` was played.
"""
site(g::Game) = query(g, "Site")
"""
event(g)

Name of event where game `g` was played.
"""
event(g::Game) = query(g, "Event")
"""
result(g)

Result of game `g`. Default is unknown, "*".
"""
result(g::Game) = query(g, "Result", "*")
"""
whiteelo(g)

Elo rating of white player in game `g`. Default is 0.
"""
whiteelo(g::Game) = intquery(g, "WhiteElo")
"""
blackelo(g)

Elo rating of black player in game `g`. Default is 0.
"""
blackelo(g::Game) = intquery(g, "BlackElo")
"""
eco(g)

ECO code for opening in the game `g`.
"""
eco(g::Game) = query(g, "ECO")
"""
eventdate(g)

Date event started in which game `g` was played.
"""
eventdate(g::Game) = datequery(g, "EventDate")
"""
plycount(g)

Ply count of game `g`.
"""
plycount(g::Game) = intquery(g, "PlyCount")

movetext(g::Game) = g.movetext

intresult(g::Game) = RESULT_HASH[query(g, "Result", "1/2-1/2")]

"""
whiteev(g)

Expected score of the white player based on Elo rating in game `g`.

"""
whiteev(g::Game,evslope=400,ev0=0) = ev0 + 1. / (1. + 10^((blackelo(g)-whiteelo(g)) / evslope))
"""
blackev(g)

Expected score of the black player based on Elo rating in game `g`.
"""
blackev(g::Game,evslope=400,ev0=0) = ev0 + 1. / (1. + 10^((whiteelo(g)-blackelo(g)) / evslope))
"""
whitescore(g)

Score for white in game `g`, based on the result.
"""
whitescore(g::Game) = 0.5*(intresult(g) + 1)
"""
blackscore(g)

Score for black in game `g`, based on the result.
"""
blackscore(g::Game) = 0.5*(1 - intresult(g))
"""
whiteperfelo(g)

Performance rating for white based on the result in game `g`.
"""
whiteperfelo(g::Game) =  intresult(g)*400 + blackelo(g)
"""
blackperfelo(g)

Performance rating for black based on the result in game `g`.
"""
blackperfelo(g::Game) = -intresult(g)*400 + whiteelo(g)

"""
isdecisive(g)

Boolean test of whether game `g` had a decisive result.
"""
isdecisive(g::Game) = intresult(g) != 0

const STATE_HEADER = 0
const STATE_MOVES = 1
const STATE_NEWGAME = 2

isblank(line) = all(isspace, line)


"""
sortpgnfile(filename)

Sort the games in a PGN file. (Implementation incomplete.)
"""
function sortpgnfile(pgnfilename, outfile)
  data = readpgn(pgnfilename)
  datasorted=sort(data, by=cpsort)
  f = open(outfile, "w")
  for d in datasorted
    write(f, repr(d))
  end
  close(f)
end


"""
browsepgn(filename)

Browse the games in a PGN file, one by one.
"""
function browsepgn(pgnfilename)
  data = readpgn(pgnfilename)
  datasorted = sort(data, by=cpsort)
  n = 1
  while true
    println("=========================== GAME $n ===========================")
    gamestats(datasorted[n])
    key = read(STDIN,Char)
    if key == 'q'
      break
    elseif key == 'j'
      n += 1
    elseif key == 'k'
      n -= 1
    elseif key == 'J'
      n += 10
    elseif key == 'K'
      n -= 10
    end
    n = n % length(datasorted)  # wrap around
  end
end


function main()
  games = readpgn(ARGS[1], verbose=true)
  println("Read $(length(games)) games.")
  for g in games
    show(g)
  end
end

PROGRAM_FILE == "PortableGameNotation.jl" && main()
end
