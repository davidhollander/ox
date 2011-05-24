Ox is the open source, server-layer library for a web application I am working on. While the application-layer will remain closed source for now, I will try to feed a good amount of code into this library.


## Goals

The focus of this project is to generate reusable logic, not components. This will be a collection of thematically related functions I use for servers, as oppossed to a single configurable black box. It will use a few C dependencies to bootstrap the process, by may eventually move to the LuaJIT FFI to make system calls directly. One should eventually be able to use the functions here to construct their own, custom high performance HTTP servers, databases, caches, or JSON backends.


## Rationale

LuaJIT is currently the fastest implementation of a dynamic language, with the possible exception of a propietary common lisp implementation or two. Because of its speed, teams dealing with application level problems are free to handle a high volume of data and connections in creative ways without taking on the tech debt of rolling custom services in C or another compiled language. This is increasingly important for applications where the View and Controller layer exists clientside in JavaScript; the server language must be able to pull its weight as a Model provider.

Lua's ability to return multiple values from functions and limited number of core types results in easy error handling, without resorting to try\except blocks as one would in Python. Furthermore, first class functions and full lexical scoping (similar to Scheme) go a long way in aiding callback based asynchronous development.


## Coding Guidelines

The robustness of an application is largely determined by choices on how to handle state. Here are the coding guidelines for Lua I will be observing for this project:
1. When dealing with small amounts of state accessed in one location, use a closure.
2. When handling large amounts of state, use a table of tables.
3. Don't use objects to handle state. Unless it is a new algorithmic data structure, that benchmarks faster than the naive table implementation in LuaJIT for a sane N. Which is fairly unlikely for this project.
4. Avoid metatables.
5. Don't use coroutines to make generators. Use a closure.
6. Don't use coroutines to make something asynchronous. Use a callback.


## HTTP Specific

KeepAlive is an unnecessary feature that increases context weight and will not be implemented. Read the following for a detailed discussion in regards to HAProxy: http://stackoverflow.com/questions/4139379/http-keep-alive-in-the-modern-age


## Performance

ab -c 1000 -n 100000 indicates serving files or dynamic pages from memory with LuaJIT can be at least as fast as nginx, though this is by no means a conclusive test.


## Status

Early in development.
LuaJit can be downloaded here: http://luajit.org/download.html
If using LuaJIT and not Lua5.1, here is how to add readline support: http://dhllndr.posterous.com/adding-readline-support-to-luajit2
Run or read the comments in ubuntuinstall script for dependencies.
Run or read "tests/ex_website.lua" to get started.
