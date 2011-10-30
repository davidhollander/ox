Ox is a lightweight, asynchronous, callback-based server library for developing fast servers, web applications, or data services using LuaJIT.

## Status
The Ox1 branch is a functional event based server and client for both Lua and LuaJIT. Requires nixio, json4lua, luazlib, luahttp-parser.
The current branch reduced dependencies to nixio, but body parsing remained incomplete.
Other branches moved the server to the LuaJIT FFI and eliminated intermediate dependencies.
A new LuaJIT only repository or master branch should be released on November 3rd, with an altered API and body parsing.
Event sources should include tcp, udp, unix datagrams, inotify.

## Install
* luarocks install nixio
* make install

## Getting started
    luajit examples/helloworld.lua
    http://localhost:8080/
