nix run nixpkgs#dasm ./decoder-regression.test.dasm -- -odecoder-regression.test.out
../zig-out/bin/atari2600.exe --decode decoder-regression.test.out > decoder-regression.test.decoded.dasm
diff --unified decoder-regression.test.dasm decoder-regression.test.decoded.dasm
result=$?
rm decoder-regression.test.out
rm decoder-regression.test.decoded.dasm
exit $result
