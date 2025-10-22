# utils

## trash
```
  USAGE: trash [files].. (--flags)
  --version      print version
  --s --silent   dont print trash paths
  --h --help     display help

  Version:
    v0.1 ff47595 (25.10.23 00:04)
```

## move
```
Usage: move src.. dest (--flags)
  Move or rename a file, or move multiple files into a directory.
  When moving multiple files last file must be a directory.

  Clobber Style:
    (default)  error with warning
    -f --force    overwrite the file
    -t --trash    move to trash         $trash/TRASH_{unixtimesamp}__{dest_basename}
    -b --backup   rename the dest file  {dest}.backup~

    If mulitiple clober flags the presidence is (backup > trash > force > default).

  Other Flags:
    --version     print version
    -r --rename   just replace the basename with dest
    -s --silent   dont print clobber info
    -v --verbose  print the move paths
    -h --help     print this help

  Version:
    v0.1 ff47595 (25.10.23 00:04)
```

