# Makefile for PortPeek

.PHONY: help install test lint clean

help:
	@echo "PortPeek Makefile"
	@echo ""
	@echo "Usage:"
	@echo "  make install    - Install dependencies (if needed)"
	@echo "  make test       - Run tests"
	@echo "  make lint       - Run shellcheck linting"
	@echo "  make clean      - Clean temporary files"
	@echo "  make help       - Show this help message"

install:
	@echo "Making portpeek.sh executable"
	chmod +x bin/portpeek.sh
	@echo "Installation complete"

test:
	@echo "Running tests..."
	./tests/test_portpeek.sh

lint:
	@echo "Running shellcheck..."
	shellcheck bin/portpeek.sh

clean:
	@echo "Cleaning temporary files..."
	rm -rf .temp
	@echo "Clean complete"

setup: install
	@echo "Setup complete"