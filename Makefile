LUA=$(shell luajit -e "print(package.path:match(';(.-)?.lua'))")
#LUA="/usr/local/share/lua/5.1"

default:
	@echo ""
	@echo "  install: copy to $(LUA)ox"
	@echo "  remove: remove from $(LUA)ox"
	@echo ""

install:
	cp ox.lua $(LUA)
	cp -r ox/ $(LUA)

remove:
	rm -r $(LUA)ox.lua $(LUA)ox/
