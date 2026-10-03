# B-LAN verify gate
# make verify        — flutter analyze + flutter test + android debug apk (task close-out gate)
# make quick-verify  — flutter analyze + flutter test (pre-commit; no apk build)
# make build-linux   — optional linux desktop debug build (not part of verify)
# make install-hooks — lefthook install (pre-commit runs make quick-verify)

FLUTTER ?= flutter

.PHONY: help lint fmt test build build-linux verify quick-verify clean install-hooks

help:
	@echo "Targets:"
	@echo "  make verify        - analyze + test + android debug apk (task close-out gate)"
	@echo "  make quick-verify  - analyze + test (pre-commit; fast)"
	@echo "  make lint          - flutter analyze"
	@echo "  make fmt           - dart format lib test"
	@echo "  make test          - flutter test"
	@echo "  make build         - flutter build apk --debug"
	@echo "  make build-linux   - flutter build linux --debug (optional, not in verify)"
	@echo "  make clean         - flutter clean"
	@echo "  make install-hooks - lefthook install"

lint:
	$(FLUTTER) analyze

fmt:
	$(FLUTTER) dart format lib test

test:
	$(FLUTTER) test

build:
	$(FLUTTER) build apk --debug

build-linux:
	$(FLUTTER) build linux --debug

verify: lint test build

quick-verify: lint test

clean:
	$(FLUTTER) clean

install-hooks:
	lefthook install
