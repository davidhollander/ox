Ox is the lightweight, asynchronous, callback-based server library for developing fast servers, web applications, or data services.
It will use a few C dependencies to bootstrap development, but may move entirely to the LuaJIT FFI in the future.


## Rationale

LuaJIT is currently the fastest implementation of a dynamic language, possibly barring propietary common lisp implementations. Because of its speed, teams dealing with application level problems are free to handle a high volume of data and connections in creative ways, without taking on the tech debt of rolling custom services in C or another compiled language. This is increasingly important for applications where the View and Controller layer exists clientside in JavaScript; the server language must be able to pull its weight as a Model provider.

Lua's ability to return multiple values from functions and limited number of core types results in easy error handling, without resorting to try\except blocks as one would in Python. Furthermore, first class functions and full lexical scoping (similar to Scheme) go a long way in aiding callback- based asynchronous development.

## Install

1. Grab LuaJIT2: http://luajit.org/download.html
2. Add readline support to LuaJIT2 (optional): http://dhllndr.posterous.com/adding-readline-support-to-luajit2

if debian\ubuntu:

3. "make apt"

else:

4. Install luarocks: apt-get install luarocks (also available: http://luarocks.org/en/Download )
5. Install the dependencies with rock files:
    luarocks install nixio
    luarocks install json4lua 
    luarocks install http-parser
6. Install lua-zlib: https://github.com/brimworks/lua-zlib

all:

7. "make install". Or copy core.lua, http.lua, file.lua to [Lua Module Folder]/ox/

## Getting started

Open "mysite.lua" in a text editor.
Require packages:

   local core = require'ox.core'
   local http = require'ox.http'
Add a root handler:

    http.GET ['^/$'] = function(c)
      http.reply(c, 200, "Hello World")
    end
Add a server:

    http.server(8080, http)
Start the server:

    print(8080)
    core.loop()

Run "luajit mysite.lua" or "lua mysite.lua" and visit http://localhost:8080

## Documentation

http://davidhollander.github.com/ox/

## Design Notes

The robustness of an application is largely determined by choices on how to handle state. This project will remain lightweight by avoiding coroutines or metatable objects, and deferring to closures and functional organization where possible. Coroutines add significant overhead while decreasing flexibility and encourage making sequential rather than parallel subrequests. Also, HTTP KeepAlive is an unnecessary feature that increases context weight and will not be implemented. Read the following for a more detailed discussion in relation to HAProxy: http://stackoverflow.com/questions/4139379/http-keep-alive-in-the-modern-age
