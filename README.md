# scdLocker

## Requirments

### GHC
 - https://www.haskell.org/ghc/
 - on debian: apt-get install ghc

### cabal-install
 - http://hackage.haskell.org/package/cabal-install
 - on debian: apt-get install cabal-install

### zlib library and headers
 - on debian: apt-get install zlib1g zlib1g-dev
 
### Haskell dbus library
 - cabal update
 - cabal install dbus
 
### Haskell command library
 - cabal update
 - cabal install command
 
### Haskell Concurrent Extra
 - cabal update
 - cabal install concurrent-extra
 
 ## Build and Install
 - make 
 - sudo make install
 
 ## Setup scd_locker systemd user service
 - systemctl --user daemon-reload
 - systemctl --user enable scd_locker
 - systemctl --user start scd_locker
