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
