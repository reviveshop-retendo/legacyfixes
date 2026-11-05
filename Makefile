.PHONY: all build repo clean debs

all: build

build:
	./scripts/docker-build.sh

repo:
	./scripts/make-repo.sh

debs:
	@ls -lh build/debs/*.deb

clean:
	rm -rf build
	rm -rf packages/*/.theos packages/*/packages packages/*/obj
	rm -f repo/Packages repo/Packages.gz repo/Release repo/Release.gpg repo/InRelease
	rm -rf repo/debs
