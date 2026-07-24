ROM     := game.nes
BUILD   := build
EMU_WEB := $(HOME)/work/github.com/GOROman/cluade-famicom-emu/web
PORT    := 8000

SRC := $(wildcard src/*.s) $(wildcard assets/*.s)

.PHONY: all run clean

all: $(ROM)

$(ROM): $(BUILD)/main.o nes.cfg
	ld65 -C nes.cfg -o $@ $(BUILD)/main.o
	@ls -l $@

$(BUILD)/main.o: $(SRC) buildinfo | $(BUILD)
	ca65 -g src/main.s -o $@

# タイトル画面用のビルド情報 (Git リビジョン + 日付) を毎回再生成
.PHONY: buildinfo
buildinfo:
	python3 tools/gen_buildinfo.py

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
