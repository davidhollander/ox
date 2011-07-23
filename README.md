Ox is the lightweight, asynchronous, callback-based server library for developing fast servers, web applications, or data services.

## Status
Currently serves single host http web applications at speeds equivalent to nginx static files in naive benchmarks.

A blogging example application using tokyocabinet is in development to feature many common use cases.

Upon completion of oxblog, the spec for the first version will solidify, with html documentation and a .rock file being added.

Later, experimental branches including virtual hosts, RPC, and a rewrite for the LuaJIT FFI can be merged in, depending on feature priority and demand.

## Install
### Debian\Ubuntu
    make apt
    make install

### Other
Install the dependencies with rock files:

* luarocks install nixio
* luarocks install json4lua 
* luarocks install lua-http-parser

Install lua-zlib: https://github.com/brimworks/lua-zlib

## Getting started
    luajit examples/helloworld.lua
    http://localhost:8080/
