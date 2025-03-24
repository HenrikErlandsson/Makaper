# Makaper
A mini macro language for common AmigaOS tasks such as file processing and conversions. Accompanied by a "unit" test source.

* No dependencies
* Does not add any code/modify the binary unless a function is used.
* Fewer lines of more readable code for common, dull tasks.
* Reasonably (size) optimized code.
* Moderate sanity check on parameters e.g. 0-check on MAK_FREE, MAK_CLOSELIBS.

## Gist

    INCLUDE "Makaper.S"
    MAK_INIT
    MAK_OPENLIBS
    MAK_IO
    MAK_WRITELN "Hello, world!"
    MAK_CLOSELIBS
    rts

## Example use cases
* As a general wrapper for any utility, or a demo or game that needs loading/processing/saving.
* Similar functions as in a BIOS or boot ROM monitor, examining and modifying memory or files
* File format converters
* File generators and processors
* Piped Shell commands
  
