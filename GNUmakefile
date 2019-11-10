
build/scdLocker: src/locker.hs
	mkdir -p build
	cp -r src build
	ghc build/src/locker.hs -o build/scdLocker

install: build/scdLocker
	cp build/scdLocker ~/bin/
clean:
	rm -rf build
