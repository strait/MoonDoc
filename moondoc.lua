#!/usr/bin/env lua

local lfs = require 'lfs'
local lp = require 'lpeg'
local lx = require 'moonloop.list'
local util = require 'moonloop.util'
local tbx = require 'moonloop.tableAux'
local lc = lp.locale()

local args = {...}

local optTest, optNosort, optHeading
local i = 1
local files = {}
local out
local result
local resMap = {}
local currentFile
local currentLine = 1
local preCodeZone  -- The beginning zone allowing testing-only code.
local headingWait  -- In the initial section and waiting for a heading.

local function incrLine ()
    currentLine = currentLine + 1
end

while i <= #args do
    local carg = args[i]
    if carg == '--test' then
        optTest = true
    elseif carg == '--nosort' then
        optNosort = true
    elseif carg == '--heading' then
        i = i + 1
        local arg = tonumber(args[i])
        if arg and arg > 0 and arg < 4 then
            optHeading = arg
        end
    else
        files[#files + 1] = carg
    end
    i = i + 1
end

if #files == 0 then
    error('At least one Lua source file must be listed.')
end

local nl = lp.P'\n' / incrLine
-- Used for counting lines.
local any = nl + 1
local sp = lp.S(' \t')
local blankline = sp^0 * nl
local idName = (lc.alpha + lp.P'_') * (lc.alnum + lp.P'_')^0

local function procAssert (first, second)
    if optTest then
        local message = '[==[Test failed in file '..currentFile..', line '..currentLine..':\n'..first..' == '..second..']==]'
        out = out..'util.assert('..first..', '..second..', '..message..')\n'
    elseif not preCodeZone then
        out = out..'\t-- '..first..' == '..second..'\n'
    end
end

local function procExLine (line)
    if optTest then
        out = out..line..'\n'
    elseif not preCodeZone then
        out = out..'\t'..line..'\n'
    end
end

local function exampleEnd ()
    -- The pre code can only be the first example.
    preCodeZone = false
end

local function addNL ()
    if not optTest then
        out = out..'\n'
    end
end

local function procDesc (text)
    if not optTest then
        if headingWait then
            if not string.match(text, "^=S") then
                if optHeading then
                    -- If heading tag not found and heading is given as an option.
                    text = '=S'..optHeading..' '..text
                else
                    -- Then first paragraph was meant to be descriptive.
                    preCodeZone = false
                end
            end
            headingWait = false
        else
            preCodeZone = false
        end
        text = string.gsub(text, 'nil', '`nil`')
        text = string.gsub(text, 'true', '`true`')
        text = string.gsub(text, 'false', '`false`')
        out = out..text..'\n'
    end
end

local function procFun (name, arguments)
    if not optTest then
        out = '* '..name..' '..arguments..'\n\n'..out
        if optNosort then
            result = result..out
        else
            resMap[name] = out
        end
    else
        resMap[name] = out..'\n'
    end
    out = ''
end

local function prelimStart ()
    preCodeZone = true
    headingWait = true
end

local function prelimEnd ()
    headingWait = false
    preCodeZone = false
    result = out
    out = ''
end

local endent = lp.P(']]') * blankline^1
local endp = (nl * blankline^1 + nl * #endent) / addNL

local dqWord = (lp.P'if' + lp.P'elseif' + lp.P'while' + lp.P'until') * sp^1 + lp.P'--'
local eql = sp^1 * lp.P'==' * sp^1
local exline = sp^1 * -dqWord * lp.C((any - (nl + eql))^1) * eql * lp.C((any - nl)^1) / procAssert +
    sp^1 * lp.C((any - nl)^1) / procExLine
local exsect = (exline - endp) * (nl * (exline - endp))^0
local desc = (any - endent) * (any - endp)^0 / procDesc * endp
local example = #sp * exsect * (endp * #sp * exsect)^0 * endp / exampleEnd

local initEntry = lc.space^0 * lp.P('--[[') * blankline^1 / prelimStart * 
    (example + desc)^1 * endent / prelimEnd

local funcEntry = lp.P('--[[') * blankline^1 * (example + desc)^1 * endent *
    (lp.P'local' * sp^1)^-1 * lp.P'function' * sp^1 *
    lp.C(idName) * sp^0 * lp.C(lp.P'(' * (1 - lp.P')')^0 * lp.P')')  / procFun

local function anywhere (p)
    return lp.P{p + any * lp.V(1)}
end

local function runTests (file)
    result = [[
        local util = require("moonloop.util")
        local _newG = {}
        if type(...) == "table" then
            for k,v in pairs(...) do
                _newG[k] = v
            end
        end
        setmetatable(_newG, {__index = _G})
        setfenv(1, _newG)
        ]]..result
    local f = loadfile(file)
    local mod = f('testmod')
    -- Make test name globally available.
    if not mod then
        mod = testmod
    end
    -- run the tests
    local tests = assert(loadstring(result))
    tests(mod)
    print(currentFile..': All tests passed!')
end

for i=1,#files do
    out = ''
    result = ''
    currentFile = files[i]
    local text = util.readFile(currentFile)
    lp.match(initEntry^-1 * anywhere(funcEntry)^0, text)
    if optTest or not optNosort then
        for k,v in tbx.pairsByKeys(resMap) do
            result = result..v
        end
    end
    if optTest then
        -- run tests
        runTests(currentFile)
        currentLine = 1
    else
        io.write(result)
    end
    resMap = {}
end
    

    

        
