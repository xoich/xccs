#!/usr/bin/env lua
local lpeg
if fengari then
  lpeg = dofile('lulpeg.lua')
else
  lpeg = require('lpeg')
  local _inspect = require "inspect"
  function inspect (e) print(_inspect(e)) end
end
-------------------------- [Parser] ----------------------------
lpeg.locale(lpeg)
local sp1 = lpeg.space
local space = (sp1^1 + (lpeg.P'//' * (1 - lpeg.P'\n')^0 * (lpeg.P"\n" + -1)))^0
------------------- Math Expressions Grammar -------------------
local mexp
do
  local Number = (lpeg.P"-"^-1 * lpeg.R("09")^1) / tonumber * space
  local TermOp = lpeg.C(lpeg.S("+-")) * space
  local FactorOp = lpeg.C(lpeg.S("%*/")) * space
  local Open = "(" * space
  local Close = ")" * space
  local Minus = lpeg.P("-") / "u-" * space
  local Name = lpeg.C(lpeg.alpha * (lpeg.alpha + lpeg.digit + "_")^0) * space
  local function node(p)
    return p / function(left, op, right) return { op, left, right } end
  end
  local function addnode(t, op, right)
    return {op, t, right}
  end
  local function LAloop(op, el)
    return lpeg.Cf(node(el * op * el) * lpeg.Cg(op * el)^0, addnode)
  end
  local V = lpeg.V
  mexp = lpeg.P{
    "Exp";
    Exp = V"Term" + V"Factor" + V"Unary",
    Term = LAloop(TermOp, V"Factor" + V"Unary"),
    Factor = LAloop(FactorOp, V"Unary"),
    Unary = Number + Name + Open * V"Exp" * Close + lpeg.Ct(Minus * V"Unary")
  }
end
-------------------------- XCCS Grammar ------------------------
local parse_xccs
do
  local oper = lpeg.C(lpeg.S"+.|\\") * space
  local operseq = lpeg.C(lpeg.S"+.|") * space
  local varname = lpeg.C(lpeg.alpha * (lpeg.alpha + lpeg.digit + "_")^0) * space
  local name =
    lpeg.C((lpeg.P"'"^-1) * lpeg.alpha * (lpeg.digit + lpeg.alpha + '_')^0) * space
  local eq = lpeg.P"=" * space
  local open, close    = "(" * space, ")" * space
  local aopen, aclose  = "<" * space, ">" * space
  local sopen, sclose  = "[" * space, "]" * space
  local copen, cclose  = "{" * space, "}" * space
  local relop = "/" * space
  local lsep = "," * space
  local rngisep = ":" * space
  local rngsep = ";" * space
  local bindname = (lpeg.C"proc" + lpeg.C"set") * sp1 * space
  local let = "let" * sp1 * space
  local V, Ct, Cc, Cp = lpeg.V, lpeg.Ct, lpeg.Cc, lpeg.Cp
  local err_pos
  local function update_err_pos (text, pos)
    err_pos = pos
    return pos
  end
  local ERR_POS = lpeg.P(update_err_pos)
  local function rangedlist(el)
    local lsel = Ct(el * (lsep * el)^0)
    local rgel = Ct(V"ranges" * lsel)
    local lsrg = Ct(rgel * (lsep * rgel)^0)
    return (lsel * lsep * lsrg) + lsel * Cc({}) + Cc({}) * lsrg + Cc({}) * Cc({})
  end
  local function packwithpos(pos, ...)
    return {pos = pos, ...}
  end
  local G = lpeg.P{
    "xccs";
    xccs = Ct((V"ccsbind" + V"varbind")^0),
    ccsbind = ERR_POS * Cp() * bindname * V"ranges"^-1 * V"cname" * eq * Ct(V"exp")
      / packwithpos,
    varbind = ERR_POS * (Cp() * let * Cc"var" * varname * eq * mexp)
      / packwithpos,
    exp = V"term" * (oper * V"term")^0,
    term = (open / "(") * V"exp" * (close / ")") + V"oseq" + V"set" + V"rel" + V"cname",
    cname = V"pname" + name,
    pname = Ct(Cc("pn") * name * V"plist"),
    plist = open * (mexp * (lsep * mexp)^0 + "") * close,
    range = Ct(name * rngisep * mexp * lsep * mexp),
    ranges = Ct(aopen * V"range" * (rngsep * V"range")^0 * aclose),
    oseq = Ct(Cc"oseq" * sopen * operseq * V"ranges" * Ct(V"exp") * sclose),
    set = Ct(Cc"set" * copen * Ct(rangedlist(V"cname")) * cclose),
    relel = Ct(V"cname" * relop * V"cname"),
    rel = Ct(Cc"rel" * V"cname" * sopen * Ct(rangedlist(V"relel")) * sclose)
  }
  G = space * G * -1
  function parse_xccs (str)
    err_pos = 1
    local tree = G:match(str)
    if tree then
      return true, tree
    else
      return false, err_pos
    end
  end
end

----------------------------------------------------------------
------------------------    Compiler   -------------------------

local eval_mexp
local function eval_mexp_op(E, mexp)
  local op = mexp[1]
  if op  == "u-" then
    return -eval_mexp(E, mexp[2])
  end
  local l,r = eval_mexp(E, mexp[2]), eval_mexp(E, mexp[3])
  if op == "-" then
    return l - r
  elseif op == "+" then
    return l + r
  elseif op == "*" then
    return l * r
  elseif op == "/" then
    return l // r
  elseif op == "%" then
    return l % r
  end
end

function eval_mexp(E, mexp)
  local t = type(mexp)
  if t == "string" then
    if E[mexp] then
      return E[mexp]
    else
      error("parameter <"..mexp.."> is not bound")
    end
  elseif t == "number" then
    return mexp
  elseif t == "table" then
    return eval_mexp_op(E, mexp)
  else
    error("bad type of arg to eval_mexp")
  end
end

local function eval_mexp_orstr(E, mexp)
  if type(mexp) == "string" then
    if E[mexp] then
      return tostring(E[mexp])
    else
      return mexp
    end
  else
    return tostring(eval_mexp(E, mexp))
  end
end

local function walkranges(E, ranges, i)
  if i > #ranges then
    coroutine.yield(true)
    return
  end
  local r = ranges[i]
  local vname, a, b = table.unpack(r)
  if b < a then error("the range end value cannot be smaller than the start value") end
  local oldvalue = E[vname]
  for j=a, b do
    E[vname] = j
    walkranges(E, ranges, i+1)
  end
  E[vname] = oldvalue
end

local function eval_range(E, r)
  return {r[1], eval_mexp(E, r[2]), eval_mexp(E, r[3])}
end

local function eval_ranges(E, rls)
  local t = {}
  for _,r in ipairs(rls) do
    table.insert(t, eval_range(E, r))
  end
  return t
end

local function rangeswalker(E, ranges)
  return coroutine.wrap(function() walkranges(E, eval_ranges(E, ranges), 1) end)
end

local function eval_pname(E, pn)
  local pls = {}
  for i=3,#pn do
    table.insert(pls, eval_mexp_orstr(E, pn[i]))
  end
  return pn[2]..'_'..table.concat(pls, '_')
end

local function eval_name(E, n)
  if type(n) == "string" then
    return n
  else
    return eval_pname(E, n)
  end
end

local function eval_rangedlist(E, rl, f)
  local t = {}
  for _, v in ipairs(rl[1]) do
    table.insert(t, f(E, v))
  end
  for _, rgandls in ipairs(rl[2]) do
    local rw = rangeswalker(E, rgandls[1])
    while rw() do
      for _, v in ipairs(rgandls[2]) do
        table.insert(t, f(E, v))
      end
    end
  end
  return table.concat(t, ", ")
end

local function eval_relpair(E, p)
  return eval_name(E,p[1]).."/"..eval_name(E,p[2])
end

local function eval_set(E, set)
  return "{" .. eval_rangedlist(E, set[2], eval_name) .. "}"
end

local function eval_rel(E, rel)
  return eval_name(E, rel[2]).."["..eval_rangedlist(E, rel[3], eval_relpair).."]"
end

local term_dispatcher

local function eval_term(E, term)
  local t = type(term)
  if t == "string" then
    return term
  else
    local e = term_dispatcher[term[1]]
    if e then
      return e(E, term)
    else
      error "eval_term: type unrecognized"
    end
  end
end

local function eval_exp(E, exp)
  local buff = {}
  for _,t in ipairs(exp) do
    table.insert(buff, eval_term(E, t))
  end
  return table.concat(buff, " ")
end

local function eval_oseq(E, oseq)
  local _, op, ranges, exp = table.unpack(oseq)
  local rw = rangeswalker(E, ranges)
  local t = {}
  while rw() do
    table.insert(t, "("..eval_exp(E, exp)..")")
  end
  return "("..table.concat(t, " "..op.." ")..")"
end

local function eval_varbind(E, b)
  E[b[2]] = eval_mexp(E, b[3])
end

local function eval_bind(E, p)
  if #p == 3 then
    return p[1].." "..eval_name(E, p[2])..' = '..eval_exp(E, p[3])
  else -- with ranges p == 4
    local t = {}
    local rw = rangeswalker(E, p[2])
    while rw() do
      table.insert(t, p[1].." "..eval_name(E, p[3])..' = '..eval_exp(E, p[4]))
    end
    return table.concat(t, "\n")
  end
end

local function postolinenumber(str, pos)
  local i = 1
  for _ in string.gmatch(string.sub(str, 1, pos), '\n') do
    i=i+1
  end
  return i
end

local function eval_xccs(tree, str)
  local E = {}
  local buff = {}
  local bindf = {proc=eval_bind, set=eval_bind, var=eval_varbind}
  for _, bind in ipairs(tree) do
    local ok, cc = pcall(bindf[bind[1]], E, bind)
    if not ok then
      return false, "Error at statement benning on line "..postolinenumber(str, bind.pos)..":\n"..cc
    end
    if cc then table.insert(buff, cc) end
  end
  return true, table.concat(buff, "\n").."\n"
end

term_dispatcher = {
  pn = eval_pname,
  oseq = eval_oseq,
  set = eval_set,
  rel = eval_rel
}

local function compile(str)
  local ok, tree = parse_xccs(str)
  if not ok then 
    local ln = postolinenumber(str, tree)
    return false, "Syntax error near line "..ln..".\n"
  end
  return eval_xccs(tree, str)
end

if not fengari then
  local f = arg[1] and assert(io.open(arg[1])) or io.input()
  local _, out = compile(f:read "a")
  io.write(out)
  f:close()
else
  return { compile = compile, parse=parse_xccs }
end
