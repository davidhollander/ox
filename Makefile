# change this to your Lua modules folder if it does not autodetect
LUA=$(shell lua -e "print(package.path:match(';(.-)?.lua'))")

default:
	@echo ""
	@echo "  apt: download and install all dependencies on ubuntu/debian"
	@echo "  install: copy to $(LUA)ox"
	@echo "  remove: remove from $(LUA)ox"
	@echo ""


apt: apt2 rocks cmake install
apt2:
	sudo apt-get install build-essential lua5.1 luarocks cmake zlib1g-dev

rocks:
	luarocks install nixio
	luarocks install lua-http-parser
	luarocks install json4lua
cmake:
	git clone https://github.com/brimworks/lua-zlib.git
	cd lua-zlib/ && cmake . && make && make install
	rm -r -f lua-zlib/

install:
	mkdir -p $(LUA)ox/
	cp core.lua $(LUA)ox/
	cp http.lua $(LUA)ox/
	cp file.lua $(LUA)ox/
	cp data.lua $(LUA)ox/
	cp session.lua $(LUA)ox/

remove:
	rm -r $(LUA)ox/
