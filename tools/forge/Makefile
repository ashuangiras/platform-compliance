.PHONY: build test lint clean install release-binaries

VERSION ?= $(shell git -C ../.. describe --tags --always --dirty 2>/dev/null || echo dev)
COMMIT  ?= $(shell git -C ../.. rev-parse --short HEAD 2>/dev/null || echo none)
DATE    ?= $(shell date -u +%Y-%m-%dT%H:%M:%SZ)
LDFLAGS  = -X main.Version=$(VERSION) -X main.Commit=$(COMMIT) -X main.Date=$(DATE)

build:
	go build -ldflags "$(LDFLAGS)" -o bin/forge .

test:
	go test -race ./...

test-integration:
	FORGE_INTEGRATION=1 go test -race -tags=integration ./...

lint:
	golangci-lint run ./...

clean:
	rm -rf bin/ dist/

install: build
	cp bin/forge /usr/local/bin/forge

release-binaries:
	mkdir -p dist
	GOOS=linux  GOARCH=amd64 go build -ldflags "$(LDFLAGS)" -o dist/forge_Linux_x86_64 .
	GOOS=darwin GOARCH=amd64 go build -ldflags "$(LDFLAGS)" -o dist/forge_Darwin_x86_64 .
	GOOS=darwin GOARCH=arm64 go build -ldflags "$(LDFLAGS)" -o dist/forge_Darwin_arm64 .
	cd dist && sha256sum forge_* > forge_checksums.txt

# Run forge against this repo (integration smoke test)
smoke:
	go run . validate ../../03-catalogs/controls/SEC/SEC-001.yaml \
	  --compliance-dir ../..
