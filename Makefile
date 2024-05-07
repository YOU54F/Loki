HOST?=arm64-apple-darwin

all: build archive
build:
	./build.sh $(HOST)

archive:
	./tarball.sh $(HOST)
	mv /tmp/$(HOST).tar.xz .