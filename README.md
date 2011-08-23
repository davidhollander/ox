Ox is a lightweight, asynchronous, callback-based server library for developing fast servers, web applications, or data services using LuaJIT.

## Status
The ox2 branch has now been merged into master, where development will continue.
The current development goal is to eliminate all C dependencies. The C lua-http-parser dependency has been removed, and a pure Lua http parser has been added. It improves upon prior Lua http parser implementations, such as the one present in Xavante, by performing bounded reads. 

The next step will be removing the nixio dependency and moving to the LuaJIT ffi. The ffi strategy for core will be to use the ffi directly without intermediaries to perform all low-level polling and socket manipulation, and provide Lua functions for the higher level asynchronous operations.

The previous master branch supporting PUC-Rio Lua has been moved from 'master' to 'ox1', whereas the master branch will strictly require LuaJIT in the future.

## Install
* luarocks install nixio
* make install

## Getting started
    luajit examples/helloworld.lua
    http://localhost:8080/
