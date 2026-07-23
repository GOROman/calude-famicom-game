ROM     := game.nes
BUILD   := build
EMU_WEB := $(HOME)/work/github.com/GOROman/cluade-famicom-emu/web
PORT    := 8000

SRC := $(wildcard src/*.s) assets/chr.s

.PHONY: all run clean

all: $(ROM)

$(ROM): $(BUILD)/main.o nes.cfg
	ld65 -C nes.cfg -o $@ $(BUILD)/main.o
	@ls -l $@

$(BUILD)/main.o: $(SRC) | $(BUILD)
	ca65 -g src/main.s -o $@

$(BUILD):
	mkdir -p $(BUILD)

# 自作エミュレータ (cluade-famicom-emu) をローカル配信してブラウザで開く。
# 起動後「ROMを開く」で $(ROM) を選択する。
run: $(ROM)
	@echo "==> http://localhost:$(PORT) を開き、「ROMを開く」で $(abspath $(ROM)) を選択してください"
	@cd $(EMU_WEB) && (python3 -m http.server $(PORT) &) && sleep 1
	open http://localhost:$(PORT)

clean:
	rm -rf $(BUILD) $(ROM)
