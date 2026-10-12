# Mikolka's alternative CPPIA Compiler

This project serves as a **proper** implementation of the CPPIA compiler for the Friday Night Funkin.

By **proper** I mean:
- Not requiring you to download an entire game's source code + dependencies (which can take around 2GBs if not more)
  - This implies no need to compile lime (which also takes a while) 
- Lightweight (everything needed to get started easily fits in the 10 Mb of space)
- Fast (Scripts compile under 10 sec. from my testing)

## How to get started

First, download the `build_cppia.sh` and place it where you like (doesn't matter where, so you can place it in your mod's root directory for instance).
Make to set the execute permission before running it. 

Then you'll need to download a [CPPIA SDK](https://github.com/FunkinCompiler/fcpkg-cdn/releases), which for this script is a ``full`` variant of ``.fcpkg`` extracted into a folder (like "cppia-sdk")

I recommend downloading from the "latest" release, but you can download a different one if you're compiling for other versions of the game.

And lastly, run the script ``./build_cppia.sh --sdk ./cppia-sdk ./cppia-src out.cppia`` where:
- `--sdk` point to your CPPIA SDK folder, where you've extracted the .fcpkg
- `./cppia-src` is a path to the code you want to compile
- `out.cppia` is the resulting file

### What's with the "cppia-src" folder?

I provided a small port of my PaRappa mod as a sanity check (in case you want to test it with a known good source)

## What is ".fcpkg"

https://github.com/FunkinCompiler/fcpkg-template-repository