#!/usr/bin/env fish
trash README.md
echo -e "# utils\n\n## move\n```" >>README.md
move --help 2>>README.md
echo -e "```\n\n## trash\n```" >>README.md
trash --help 2>>README.md
echo -e "```" >>README.md

git add .
if git commit --amend
    zig build -Dgit_hash=(git rev-parse --short HEAD) -Dversion=v0.1 -Ddate=(date +"%y.%m.%d %H:%M")
    cp ./zig-out/bin/* $exec/bin/ --force
else
    echo "commit failed release aborted"
end
