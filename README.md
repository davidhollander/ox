Ox is the lightweight, asynchronous, callback-based server library for developing fast servers, web applications, or data services.

# Status
The goals for the ox2 branch are to decouple the http server and use a pure Lua parser.

# Install
## Debian\Ubuntu
make apt
make install

## Other
Install the dependencies with rock files:
 - luarocks install nixio
 - luarocks install json4lua 
Install lua-zlib: https://github.com/brimworks/lua-zlib

# Getting started
luajit examples/helloworld.lua
http://localhost:8080/
