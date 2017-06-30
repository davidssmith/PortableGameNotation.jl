__precompile__()

module PortableGameNotation

import Base.repr, Base.length, Base.@printf

export readpgn, writepgn, Game, event, site, date, round, white, black, result,
  whiteelo, blackelo, eventdate, eco, movetext, plycount, length, movestring,
  headerstring, repr, intresult, whiteev, blackev, whitescore, blackscore,
  whiteperfelo, blackperfelo, isdecisive

type Game
  header::Dict{String, String}
  movetext::String
end

RESULT_HASH = Dict{String,Int}("1-0" => 1, "1/2-1/2" => 0, "0-1" => -1, "*" => 0)
REQUIRED_TAGS = ["Event", "Site", "Date", "Round", "White", "Black", "Result"]
DEFAULT_HASH = Dict("Event"=>"","Site"=>"","Date"=>"","Round"=>"","White"=>"",
  "Black"=>"","Result"=>"")

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
function movestring(g::Game; line=80)
  moves = split(g.movetext)
  s = String[]
  n = 0
  for m in moves
    push!(s, m)
    push!(s, " ")
    n += length(m) + 1
    if n >= line
      push!(s, "\n")
      n = 0
    end
  end
  join(s, "")
end

Base.repr(g::Game) = headerstring(g) * "\n" * movestring(g)

"""
length(g)

Number of moves in the game `g`.
"""
function length(g::Game)
  moves = split(g.movetext,".")
  n = length(moves) - 1
  return n
end

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
  if contains(y, "?")
    return Date()
  elseif contains(m, "?")
    return Date(parse(Int,y))
  elseif contains(d, "?")
    return Date(parse(Int,y), parse(Int,m))
  else
    return Date(parse(Int,y), parse(Int,m), parse(Int,d))
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
whiteev(g::Game) = 1. / (1. + 10^((blackelo(g)-whiteelo(g)) / 400.0))
"""
blackev(g)

Expected score of the black player based on Elo rating in game `g`.
"""
blackev(g::Game) = 1. / (1. + 10^((whiteelo(g)-blackelo(g)) / 400.0))
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
readpgn(filename; [header=true, moves=true, verbose=false])

Read games from PGN file `filename` and returns an array of `Game`
object.

If `header` or `moves` are set to false, they will, respectively, be
ignored. This can be used to decrease memory consumption when you don't
need the full game.
"""
function readpgn(pgnfilename; header=true, moves=true, verbose=false)
  f = open(pgnfilename,"r")
  games = Vector{Game}()
  m = String[]
  h = Dict{String,String}()
  n = 0
  state = STATE_NEWGAME
  while !eof(f)
    l = readline(f)
    if ismatch(r"^\[", l)   # header line
      state = STATE_HEADER
      fields = split(l,'\"')
      key = fields[1][2:end-1]
      val = fields[2]
      if header
        h[key] = val
      end
    elseif isblank(l) && state == STATE_HEADER
      state = STATE_MOVES  # TODO: allow for multiple blank lines after header?
    elseif !isblank(l) && state == STATE_MOVES && moves
      push!(m, chomp(l))
    elseif isblank(l) && state == STATE_MOVES
      push!(games, Game(h, join(m, " ")))
      n += 1
      if verbose
        Base.@printf "\r%d" n
      end
      state = STATE_NEWGAME
    end
    if state == STATE_NEWGAME
      m = String[]
      h = Dict{String,String}()
    end
  end
  close(f)
  if state == STATE_MOVES
    push!(games, Game(h, join(m, " ")))
  end
  return games
end

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


end
