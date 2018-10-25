
module PortableGameNotation

import Base.show, Base.length, Base.println

using Dates
using Printf

export readpgn, writepgn, Game, event, site, date, round, white, black, result,
  whiteelo, blackelo, eventdate, eco, movetext, plycount, length, movestring,
  headerstring, repr, intresult, whiteev, blackev, whitescore, blackscore,
  whiteperfelo, blackperfelo, isdecisive

mutable struct Move
  number::Int16
  side::Int8
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

const STATE_MOVE_NUMBER = 0     # currently reading a move number
const STATE_WHITE_MOVE = 1 # currently reading a white move
const STATE_BLACK_MOVE = 2
const STATE_COMMENT = 3    # currently reading a comment
const STATE_PERIOD = 4     # 1-3 periods after a move number
const STATE_SPACE = 5      # in between a move and a move or a comment
const STATE_NAG = 6        # numeric annotation glyph


function Game(header::Dict{String, String}, movetext::String; skim=false)
  # This is an alternative constructor that performs a state-based
  # single scan of the move text to parse into Move objects, hopefully
  # as quickly and efficiently as possible
  # skim=true will skip move parsing and just return a Game object
  # with headers as quickly as possible for cases in which you don't
  # care about the moves
  # TODO:
  #   - deal with precomments
  #   - deal with NAGS
  #   - deal with leading ...
  # COMMENTS
  # Comments are inserted by either a ; (a comment that continues
  # to the end of the line) or a { (which continues until a matching }).
  # Comments do not nest.
  movelist = Move[]
  if skim
    return Game(header, movelist)
  end
  move_number = 1
  prevstate = -1
  nextstate = -1
  sidetomove = SIDE_WHITE
  state = STATE_MOVE_NUMBER
  startidx = 0   # indices of substring to use next
  current_move = ""        # current move text
  current_comment = ""     # current comment text
  comment_depth = 0        # level of nested comments
  #states = zeros(Int8, length(movetext))
  for k in 1:length(movetext)
    if state == STATE_MOVE_NUMBER
      if movetext[k] == '.' # end of move number
        prevstate = state
        state = STATE_PERIOD
      elseif movetext[k] == '/' # reached a drawn result
        break  # TODO: use this for validation
      elseif movetext[k] == '-' # reached a decisive result
        break  # TODO: use this for validation
      end
    elseif state == STATE_PERIOD
      if movetext[k] == '.'  # must precede a black move
        nextstate = STATE_BLACK_MOVE
      elseif movetext[k] == ' '
        continue
      else # move next
        prevstat = STATE_PERIOD
        startidx = k
        if nextstate == STATE_BLACK_MOVE
          state = nextstate
          nextstate = -1
        else
          state = STATE_WHITE_MOVE
        end
      end
    elseif state == STATE_SPACE
      if movetext[k] == ' '
        continue  # skip spaces, not important for decisions
      elseif movetext[k] == '{'   # start of comment string
        comment_depth = 1
        startidx = k+1
        prevstate = state
        state = STATE_COMMENT
      elseif movetext[k] == '$'
        startidx = k+1
        prevstate = state
        state = STATE_NAG
      elseif movetext[k] == '*' # indeterminate result, all other results will be during STATE_MOVE_NUMBER
        break # done processing
      elseif isdigit(movetext[k]) # start of a move number
        prevstate = state
        state = STATE_MOVE_NUMBER
      else # movetext[k] != '{'   # start of a move
        if sidetomove == SIDE_WHITE # no comment on this move
          push!(movelist, Move(move_number, SIDE_WHITE, current_move, current_comment))
          println(movelist)
          prevstate = state
          state = STATE_BLACK_MOVE
          startidx = k
          sidetomove = SIDE_BLACK
        elseif sidetomove == SIDE_BLACK
          push!(movelist, Move(move_number, SIDE_BLACK, current_move, current_comment))
          move_number += 1
          prevstate = state
          state = STATE_MOVE_NUMBER
          sidetomove = SIDE_WHITE
        else
          @info "UNHANDLED STATE" state k movetext[k] prevstate current_move current_comment
          @info "movetext" movetext
          exit(1)
        end
        current_comment = ""
      end
    elseif state == STATE_WHITE_MOVE
      if movetext[k] == ' ' && startidx != -1
        # end of white move, next either comment or black move
        prevstate = state
        state = STATE_SPACE
        current_move = chomp(movetext[startidx:k-1])
      elseif movetext[k] != ' ' && startidx == -1
        startidx = k
      end
    elseif state == STATE_BLACK_MOVE
      if movetext[k] == ' '
        # end of black move, next either comment or move number
        current_move = chomp(movetext[startidx:k-1])
        prevstate = state
        state = STATE_SPACE
      end
    elseif state == STATE_COMMENT
      if movetext[k] == '}' # end of comment string
        comment_depth -= 1
      elseif movetext[k] == '{'
        comment_depth += 1
      end
      if comment_depth == 0
        current_comment = movetext[startidx:k-1]
        state = STATE_SPACE
      end
    elseif state == STATE_NAG
      if movetext[k] == ' '
        current_nag = parse(Int, movetext[startidx:k-1])
        prevstate = state
        state = STATE_SPACE
      end
    else
      #@info "UNHANDLED STATE" state k movetext[k] prevstate current_move current_comment
    end
     #idxs = findnext(r"\{.*?\}", s, curr_pos)
    #states[k] = state
  end
  #println(header)
  #println("MOVELIST>\n", movelist)
  #println(movetext)
  #println(join(states,""))
  g= Game(header, movelist)
  println(g)
  return g
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
      push!(output, str)
    end
    linelen += length(m.san) + 1
    push!(output, "$(m.san) ") # TODO: avoid string interp?
    if linelen >= line
        push!(output, "\n")
        linelen = 0
    end
    if comments && m.comment != ""
      linelen += length(m.comment) + 1
      push!(output, m.comment)
      if linelen >= line
        push!(output, "\n")
        linelen = 0
      else
        push!(output, " ")
      # TODO: wrap comments
      end
    end
    ply += 1
  end
  join(output, "")
end

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
    Base.println(movestring(g), "\n")
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
    return Date()
  elseif occursin("?", m)
    return Date(parse(Int,y))
  elseif occursin("?", d)
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
readpgn(filename; [header=true, moves=true, verbose=false])

Read games from PGN file `filename` and returns an array of `Game`
objects.

If `header` or `moves` are set to false, they will, respectively, be
ignored. This can be used to decrease memory consumption when you don't
need the full game.
"""
function readpgn(pgnfilename; header=true, moves=true, verbose=false, func=false)
  f = open(pgnfilename,"r")
  games = Vector{Any}()
  m = String[]
  h = Dict{String,String}()
  n = 0
  state = STATE_NEWGAME
  while !eof(f)
    l = readline(f,keep=false)
    if occursin(r"^\[", l)   # header line
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
      push!(m, l) # can't chomp because of ; and \n comment delimiters
    elseif isblank(l) && state == STATE_MOVES
      g = Game(h, join(m, " "))
      if func != false
        push!(games, func(g))
      else
        push!(games, g)
      end
      n += 1
      if verbose
        @printf "\r%d" n
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
    g = Game(h, join(m, " "))
    if func != false
      push!(games, func(g))
    else
      push!(games, g)
    end
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


function main()
  games = readpgn(ARGS[1])
  for g in games
    println(g)
  end
end

PROGRAM_FILE == "PortableGameNotation.jl" && main()
end
