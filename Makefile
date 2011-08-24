# change this to your Lua modules folder if it does not autodetect
LUA=$(shell lua -e "print(package.path:match(';(.-)?.lua'))")

default:
	@echo ""
	@echo "  install: copy to $(LUA)ox"
	@echo "  remove: remove from $(LUA)ox"
	@echo ""

rocks:
	luarocks install nixio

install:
	mkdir -p $(LUA)ox/
	cp core.lua $(LUA)ox/
	cp html.lua $(LUA)ox/
	cp http.lua $(LUA)ox/
	cp file.lua $(LUA)ox/
	cp data.lua $(LUA)ox/
	cp session.lua $(LUA)ox/

remove:
	rm -r $(LUA)ox/
