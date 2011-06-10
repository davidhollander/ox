# change this to your Lua modules folder if it does not autodetect
LUA=$(shell lua -e "print(package.path:match(';(.-)?.lua'))")

default:
	@echo ""
	@echo "  apt: download and install all dependencies on ubuntu/debian"
	@echo "  install: copy to $(LUA)/ox"
	@echo "  remove: remove from $(LUA)/ox"
	@echo ""
apt:
	sudo apt-get install build-essential lua5.1 luarocks cmake zlib1g-dev
	rocks
	cmake
	install
rocks:
	luarocks install nixio
	luarocks install http-parser
	luarocks install json4lua
cmake:
	git clone https://github.com/brimworks/lua-zlib.git
	cd lua-zlib
	cmake .
	make
	make install


install:
	mkdir $(LUA)/ox/
	cp core.lua $(LUA)/ox/
	cp http.lua $(LUA)/ox/
	cp file.lua $(LUA)/ox/

remove:
	rm -r $(LUA)/ox/
