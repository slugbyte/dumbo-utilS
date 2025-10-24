# coreutil replacements for dumbos like me.

## about
I lost work one too many times, by accidently overwriting data with coreutils. I made these utils to
reduce the chances that would happen again. They provide much less dangerous clobber strats.
 
### trash strategy
* files become `$trash/(basename)__(hash).trash`
* dirs and links `$trash/(basename)__(timestamp).trash`
  * if there is a conflict it will be name `$trash/(basename)__(timestap)_(random).trash`

## backup strategy
* rename file `(original_path).backup~`
  * if a backup exists it will be moved to trash

## move (mv replacement)
move or rename files without accidently replacing anything.
```
Usage: move src.. dest (--flags)
  Move or rename a file, or move multiple files into a directory.
  When moveing files into a directory dest must have '/' at the end.
  When moving multiple files last path must be a directory and have a '/' at the end.

  Clobber Style:
    (default)  error with warning
    -f --force    overwrite the file
    -t --trash    move to $trash
    -b --backup   rename the dest file

    If mulitiple clober flags the presidence is (backup > trash > force > default).
  
  Other Flags:
    --version     print version
    -r --rename   just replace the basename with dest
    -s --silent   dont print clobber info
    -v --verbose  print the move paths
    -h --help     print this help
```

## trash (rm replacement)
Move files into $trash with a naming strat that wont overwrite existing trashed files.
```
USAGE: trash files.. (--flags)
  Move files to $trash.

  --version      print version
  --s --silent   dont print trash paths
  --h --help     display help
```