git add . 
git commit 
zig build -Dgit_hash=(git rev-parse --short HEAD) -Dversion=v0.1 -Ddate=(date +"%y.%m.%d %H:%M")
cp ./zig-out/bin/* $exec/bin/ --force
