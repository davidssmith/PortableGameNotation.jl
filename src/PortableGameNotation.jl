
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

const STATE_HEADER_TAG = 0
const STATE_HEADER_VALUE = 1
const STATE_MOVE_NUMBER = 2  # currently reading a move number
const STATE_MOVE = 3         # currently reading a move
const STATE_COMMENT = 4      # currently reading a comment
const STATE_PERIOD = 5       # 1-3 periods after a move number
const STATE_SPACE = 6        # in between a move and a move or a comment
const STATE_NAG = 7          # numeric annotation glyph


function readpgn(filename::String; skim=false)
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
  #   - deal with ; moves
  # COMMENTS
  # Comments are inserted by either a ; (a comment that continues
  # to the end of the line) or a { (which continues until a matching }).
  # Comments do not nest.
  movelist = Move[]
  headers = Dict{String,String}()
  move_number = 1
  prevstate = -1
  nextstate = -1
  sidetomove = SIDE_WHITE
  state = STATE_MOVE_NUMBER
  startidx = 0   # indices of substring to use next
  current_header_tag = ""
  current_header_value = ""
  current_move = ""        # current move text
  current_comment = ""     # current comment text
  current_move_number = 0
  comment_depth = 0        # level of nested comments
  #states = zeros(Int8, length(movetext))
  for k in 1:length(movetext)
    if state == STATE_MOVE_NUMBER
      if movetext[k] == '.' # end of move number
        prevstate = state
        state = STATE_PERIOD
        # TODO: add this in: current_move_number = parse(Int, movetext[startidx:k-1])
      elseif movetext[k] == '/' # reached a drawn result
        break  # TODO: use this for validation
      elseif movetext[k] == '-' # reached a decisive result
        break  # TODO: use this for validation
      elseif movetext[k] == '['
        prevstate = STATE_NULL
        state = STATE_HEADER_TAG
        startidx = k+1
      end
    elseif state == STATE_HEADER_TAG
      if movetext[k] == ' '   # end of header tag
        current_header_tag = movetext[startidx:k-1]
        prevstate = STATE_HEADER_TAG
        state = STATE_HEADER_VALUE
        startidx = -1
      end
    elseif state == STATE_HEADER_VALUE
      if movetext[k] == '"'
        if startidx == -1
          startidx = k+1
        else
          current_header_value = movetext[startidx:k-1]
          headers[current_header_tag] = current_header_value
        end
      elseif movetext[k] == ']'
        prevstate = state
        state = STATE_MOVE_NUMBER
      end
    elseif state == STATE_PERIOD
      if movetext[k] == '.'  # must precede a black move
        sidetomove = SIDE_BLACK
      elseif movetext[k] == '{'  # comment next
        prevstate = state
        state = STATE_COMMENT
        comment_depth = 1
        startidx = k+1
      elseif movetext[k] == ' '
        prevstate = state
        state = STATE_SPACE
      elseif movetext[k] != ' '     # move next
        if current_move != ""
          push!(movelist, Move(move_number, sidetomove, current_move, current_comment))
          sidetomove = 1 - sidetomove
          current_comment = ""
          current_move = ""
        end
        prevstate = STATE_PERIOD
        state = STATE_MOVE
        startidx = k
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
        startidx = k
      else # movetext[k] != '{'   # start of a move
        if current_move != ""
          push!(movelist, Move(move_number, sidetomove, current_move, current_comment))
          sidetomove = 1 - sidetomove
          current_comment = ""
          current_move = ""
        end
        prevstate = state
        state = STATE_MOVE
        startidx = k
      end
    elseif state == STATE_MOVE
      if movetext[k] == ' ' || movetext[k] == '\n'
        prevstate = state
        state = STATE_SPACE
        current_move = chomp(movetext[startidx:k-1])
        sidetomove = 1 - sidetomove
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
  end
  g= Game(header, movelist)
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
function readpgn(pgnfilename; header=true, moves=true, verbose=false,
    prealloc=true)
  f = open(pgnfilename,"r")
  if prealloc
    NGAMESMAX = div(filesize(pgnfilename), 500)
  else
    NGAMESMAX = 1
  end
  games = Vector{Game}(undef, NGAMESMAX)
  NMOVESMAX = 512
  move_text_buffer = Vector{String}(undef, NMOVESMAX)
  h = Dict{String,String}()
  ngames = 0
  nmoves = 0
  state = STATE_NEWGAME
  while !eof(f)  # TODO: read into buffer
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
      nmoves += 1
      move_text_buffer[nmoves] = l
      #push!(m, l) # can't chomp because of ; and \n comment delimiters
    elseif isblank(l) && state == STATE_MOVES
      g = Game(h, join(move_text_buffer[1:nmoves], " "))
      ngames += 1
      if ngames <= NGAMESMAX
        games[ngames] = g
      else
        @info "overflow!" ngames
        push!(games, g)
      end
      if verbose
        @printf "\r%d" ngames
      end
      state = STATE_NEWGAME
    end
    if state == STATE_NEWGAME
      nmoves = 0
      h = Dict{String,String}()
    end
  end
  close(f)
  if state == STATE_MOVES
    g = Game(h, join(move_text_buffer[1:nmoves], " "))
    ngames += 1
    if ngames <= NGAMESMAX
      games[ngames] = g
    else
      push!(games, g)
    end
  end
  return games[1:ngames]
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
  games = readpgn(ARGS[1], verbose=true)
  println("Read $(size(games)) games.")
  for g in games
    println(g)
  end
end

PROGRAM_FILE == "PortableGameNotation.jl" && main()
end
