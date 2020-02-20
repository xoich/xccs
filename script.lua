local xccs = dofile("xccs.lua")

local cminput = js.global.cminput
local cmoutput = js.global.cmoutput

-- cminput:setValue "proc <i:1,3> a = b(i + 3) | 'c // comment"

local js = require "js"
local document = js.global.document
local compilebtn = document:getElementById("compile")
local example = document:getElementById("example")
local xccsbtn = document:getElementById("xccs")
local ccsbtn = document:getElementById("ccs")
local cwbframe = document:getElementById("cwbframe")
local cwbbtn = document:getElementById("cwbbtn")
local inwrap = document:getElementById("inwrap")
local outwrap = document:getElementById("outwrap")
local undobtn = document:getElementById("undo")
local redobtn = document:getElementById("redo")
local tutorialbtn = document:getElementById("tutorial")
local examplebtn = document:getElementById("example")

local cwbloaded = false
local visible = "xccs"
-- local jslurl = "http://example.com"
local jslurl = "https://bellard.org/jslinux/vm.html?url=buildroot-x86.cfg\z
&guest_url=https://vfsync.org/u/pccs/pub&rows=23"

local function hideall()
  outwrap.style.display = "none"
  inwrap.style.display = "none"
  cwbframe.style.display = "none"
  ccsbtn.classList:remove "active"
  xccsbtn.classList:remove "active"
  cwbbtn.classList:remove "active"
end

local function goxccs()
  hideall()
  inwrap.style.display = "block"
  xccsbtn.classList:add "active"
  visible = "xccs"
end

local function goccs()
  hideall()
  outwrap.style.display = "block"
  ccsbtn.classList:add "active"
  visible = "ccs"
end

local function gocwb()
  if not cwbloaded then
    cwbframe.src = jslurl
    cwbbtn.textContent = "CWB"
    cwbloaded = true
  end
  hideall()
  cwbframe.style.display = "block"
  cwbbtn.classList:add "active"
  visible = "cwb"
end

local function compile()
  local s = cminput:getValue()
  local _, ccstxt = xccs.compile(s)
  goccs()
  cmoutput:setValue(ccstxt)
end

local function undo()
  if visible == "xccs" then cminput:undo() end
  if visible == "ccs" then cmoutput:undo() end
end
local function redo()
  if visible == "xccs" then cminput:redo() end
  if visible == "ccs" then cmoutput:redo() end
end

undobtn:addEventListener("click", undo)
redobtn:addEventListener("click", redo)
cwbbtn:addEventListener("click", gocwb)
compilebtn:addEventListener("click", compile)
xccsbtn:addEventListener("click", goxccs)
ccsbtn:addEventListener("click", goccs)

local tutorial = {[[
// XCCS is a superset of CCS that extends CCS with:
//
// - Parameters binding.
// - Parameterised agents, actions and set names.
// - CCS operators over sequences.
// - Agent and Set definitions over ranges. 
// - Set and Relabeling lists over ranges. 
//
// Being a superset, you can use the CCS you are familiar with,
// as CCS is valid in XCCS and will compile to itself:

proc A = b . B + 'c . C // Basic operators
set Internals = {a, c}  // Set definitions
proc D = A \ Internals  // Relabeling
]],
  [[
// - Parameters Binding -

// To bind a parameter use the let keyword:
let x = 3
// on the right of the '=' there can be any arithmetical expression:
let n = (x + 2) % 3 // n = 2

// Bindings can be used to parameterise agents, sets or actions 
// names. A name can be followed by a list of parameters inside 
// parentheses:
proc MyAgent(n) = myaction(n, x)
]],
  [[
// - More on Parameters Lists for Names -

// A parameter list can also contain arithmetic:
let n = 3
proc A(n-1,n,n+1) = act((n+1) % 3)

// A parameter that was not bound in a let statement is evaluated
// to its own string value:
proc A = action(hello) // action_hello
]],
  [[
// - Set and Agent Definitions over Ranges -

// The range syntax is <itname:start,end>, end is inclusive.
// Arithmetic is again possible inside ranges:
let n = 2
proc <i:1,n+1> A(i) = a(i) . A((i+1)%(n+1) + 1)

// This is equivalent to the loop:
// for i in [1,n+1]:
//   proc A(i) = a(i) . A((i+1)%n + 1)

// More than one range can be specified by separating them with
// semicolons. In this case the iteration works like for nested loops:
proc <i:1,n;j:1,n> A(i,j) = a(i) . a(j)

// Equivalent to:
// for i in [1,n]:
//   for j in [1,n]:
//     proc A(i,j) = a(i) . a(j)
]],
  [[
// - Operators over Sequences -

// Operators over sequences are the equivalents of the mathematical
// summation notation. They are not only defined for sums though, 
// but for the three CCS operators: `+' `|' and `.'
// Their syntax is [operator ranges expression]

// As an exmaple, the mathematical notation:
// proc A = Σ_{i=1,3} (a_i . b_i)
// can be written in XCCS as:
proc A = [+ <i:1,3> a(i) . b(i)]

// Same goes for the other operators:
proc B = [| <i:1,3> a(i) + b(i)]
proc C = [. <i:1,3> a(i) | b(i)]
]], [[
// - Actions and Relabeling Lists over Ranges -

// A ranged list is a range tag followed by one or 
// more comma separated elements. These are the elements we want 
// to place in the list iteratively over the range.

// The elements that do not need iteration go at the beginning
// of the expression. After them we can have one or more ranged
// lists as defined above:

proc A = {onlyonce, <i:1,3> a(i), b(i), <j:4,6> c(j)}

// For relabeling the the only difference is that list elements 
// are not single actions but relebeling pairs.

proc RB = B[only/once, <i:1,3> a(i)/b(i)]

// End of the Tutorial. 
// For an example of XCCS use, click the button PIPE Example.
]]
}

local tutorialindex = 0

for i=1,#tutorial-1 do
  tutorial[i] = tutorial[i].."\n\n// You can try to compile this to see the result and experiment with\n"
  tutorial[i] = tutorial[i].."// the code, otherwise click Next for the next part of the tutorial."
end
for i=1,#tutorial do
  tutorial[i] = "// --- XCCS Tutorial "..i.."/"..#tutorial.." ---\n\n"..tutorial[i]
end

local function tutorialnext()
  tutorialindex = tutorialindex + 1
  goxccs()
  cminput:setValue(tutorial[tutorialindex])
  if tutorialindex == #tutorial then
    tutorialbtn.textContent = "End - Restart Tutorial"
    tutorialindex = 0
  else
    tutorialbtn.textContent = "Next"
  end
end

tutorialbtn:addEventListener("click", tutorialnext)


local pipeexample = [=[
// Implementation of the PIPE Buffer in XCCS

let nc = 5 // number of cells
let ns = 2 // number of symbols

//  Basic Cell Agent
proc LB(C) = [+ <i:1,ns> in(i) . 'out (i) . LB(C)]

// Relabaling for Buffer Out
proc LB(C,nc+1) =  LB(C)[<i:1,ns> d(nc,i) / out(i)]

// Relabaling for Buffer In
proc LB(C,0) =  LB(C) [<i:1,ns> d(0,i) / in(i)]

// Relabaling for Central Cells
proc <i:1,nc> LB(C,i) = LB(C) [<s:1,ns> d(i,s) / in(s), <s:1,ns> d(i-1,s) / out(s)]

// Put all in parallel
set Internals = {<s:1,ns;i:0,nc> d(i,s)}
proc  LB =  [| <i:0,nc+1> LB(C,i)] \ Internals
]=]

examplebtn:addEventListener("click", function() goxccs() cminput:setValue(pipeexample) end)
