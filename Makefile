ROM := build/dashcore.gb
SRC := $(wildcard src/*.asm src/*.inc)

all: $(ROM)

$(ROM): $(SRC)
	@mkdir -p build
	rgbasm -Wall -I src -o build/main.o src/main.asm
	rgblink -n build/dashcore.sym -m build/dashcore.map -o $@ build/main.o
	rgbfix -v -p 0xFF -m 0x03 -r 0x02 -n 0 -j -t "DASH CORE" $@

test: $(ROM)
	.venv/bin/python -I tools/test_rom.py $(ROM)

clean:
	rm -rf build

.PHONY: all test clean

dist: $(ROM)
	@mkdir -p dist
	cp $(ROM) dist/DashCore.gb
	git archive --format=zip --prefix=DashCore-source/ -o dist/DashCore-source.zip HEAD
	@echo "dist/ ready (source zip is from the last commit)"

.PHONY: dist
