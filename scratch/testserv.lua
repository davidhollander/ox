--xserv.lua
local ox=require'ox'
ox.makeserver(8080,ox.accepthttp)
ox.makeserver(8888,ox.acceptworker)
ox.loop()
