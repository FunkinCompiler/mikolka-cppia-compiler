#!/usr/bin/env bash
# Compiles a mod's scripted classes to a single .cppia the game can load.
# Usage: ./build_cppia.sh [--sdk <sdk-dir>] <script-dir> <output.cppia> [Class ...]

# SDK here contains `export_classes.info`, `cppia.hxml` as well as libraries used by CPPIA to compile your mod
# https://github.com/FunkinCompiler/fcpkg-cdn/releases
# Make sure to download the `full` version, not the `shallow` one 

# A full example of it might be:
# ./build_cppia.sh --sdk ./cppia-sdk ./my-mod/scripts/cppia-src/ MyMod.cppia

# You are also able (as seen by 'Class ...') to write specific classes you want to compile.
# IE: [MyModule YourModule OurModule]

set -euo pipefail

SDK=""
KEEP_RESOURCES=0
REMOVE_CPPIA_TEMP_SDK=0
while [ "$#" -gt 0 ]; do
	if [ "$1" = "--keep-resources" ]; then
		KEEP_RESOURCES=1; shift
	elif [ "$1" = "--sdk" ]; then
		SDK="$2"; shift 2
	else
		break
	fi
done

if [ "$#" -lt 2 ]; then
	echo "Usage: $0 [--sdk <sdk-dir>] <script-dir> <output.cppia> [Class ...]" >&2
	exit 1
fi

SCRIPT_DIR="$1"; shift
OUTPUT="$1"; shift
CLASSES=("$@")

if [ ! -d "$SCRIPT_DIR" ]; then
	echo "No such script directory: $SCRIPT_DIR" >&2
	exit 1
fi

SCRIPT_DIR="$(cd "$SCRIPT_DIR" && pwd)" || exit 1

if [ "${OUTPUT#/}" = "$OUTPUT" ] && [ "${OUTPUT#[A-Za-z]:}" = "$OUTPUT" ]; then
	OUTPUT="$(pwd)/$OUTPUT"
fi

if [ -z "$SDK" ]; then
	echo "No SDK specified! You need to point at valid fcpkg directory." >&2
	exit 1
fi

# Helper functions
towin() {
	if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else echo "$1"; fi
}

haxe_std_path() {
  local path
  local candidates=(
    "${HAXE_STD_PATH:-}"
    "/usr/share/haxe/std"
    "/usr/local/lib/haxe/std"
    "/usr/local/share/haxe/std"
    "/opt/homebrew/lib/haxe/std"
    "/opt/homebrew/share/haxe/std"
    "/opt/local/lib/haxe/std"
    "C:/HaxeToolkit/haxe/std"
    "C:/Program Files/HaxeToolkit/haxe/std"
    "C:/Haxe/haxe/std"
    "$HOME/haxe/std"
    "$HOME/HaxeToolkit/haxe/std"
  )

  for path in "${candidates[@]}"; do
    if [[ -n "$path" && -f "$path/Std.hx" ]]; then
      # Strip trailing slashes, preserving the root directory.
      printf '%s\n' "${path%/}"
      return 0
    fi
  done

  printf 'Haxe std folder not found in common locations\n' >&2
  return 1
}

# finish



GENERATED="$(mktemp -t cppia-XXXXXX.hxml)"
trap 'rm -f "$GENERATED"' EXIT

GEN_CPPIA_INFO="$(mktemp -t export_classes_XXXXXX.info)"
trap 'rm -f "$GENERATED"' EXIT

# Let's check the env


if [ -n "$SDK" ]; then
	SDK_ABS="$(cd "$SDK" && pwd)" || exit 1

	if [ ! -f "$SDK_ABS/cppia.hxml" ]; then
		echo "SDK at $SDK_ABS has no cppia.hxml, are you sure this is FCPKG package?"
		exit 1
	fi
	if [ ! -f "$SDK_ABS/export_classes.info" ]; then
		echo "SDK at $SDK_ABS is not compiled! I'll temporary compile it for you."
		echo "Please re-compile it using Funkin Compiler!"
		(cd "$SDK_ABS" && HAXELIB_PATH="$SDK_ABS" haxe "funkin.hxml" -D scriptable) 
		REMOVE_CPPIA_TEMP_SDK=1
		echo "Re-compilation done!"
	fi

	HOST_CLASSES="$(towin "$SDK_ABS/export_classes.info")"
	# sed "s|\${FUNKIN_ROOT}|$(towin "$ROOT")|g" "$SDK_ABS/cppia.hxml" > "$GENERATED"
	echo "Using SDK $SDK_ABS"
fi

if [ "${#CLASSES[@]}" -eq 0 ]; then
	while IFS= read -r f; do
		rel="${f#"$SCRIPT_DIR"/}"
		CLASSES+=("$(echo "${rel%.hx}" | tr '/' '.')")
	done < <(find "$SCRIPT_DIR" -type f -name '*.hx' | sort)
fi

if [ "${#CLASSES[@]}" -eq 0 ]; then
	echo "No .hx files found under $SCRIPT_DIR" >&2
	exit 1
fi
# Set the replacement values here.
CPPIA_SOURCE=$(towin "$SCRIPT_DIR")

CLASS_NAMES=$(for cls in "${CLASSES[@]}"; do
  echo "$cls"
done)

CLASS_NAMES_ARRAY=''
for cls in "${CLASSES[@]}"; do
	if [ -n "$CLASS_NAMES_ARRAY" ]; then CLASS_NAMES_ARRAY="$CLASS_NAMES_ARRAY,"; fi
	CLASS_NAMES_ARRAY="$CLASS_NAMES_ARRAY'$cls'"
done

CPPIA_DLL="$GEN_CPPIA_INFO"
DEBUG_FLAG='--debug'
CPPIA_OUT=$(towin "$OUTPUT")

# HXML substitution
while IFS= read -r line || [[ -n $line ]]; do
    line=${line//'$CPPIA_SOURCE'/"$CPPIA_SOURCE"}
    line=${line//'$CLASS_NAMES_ARRAY'/"$CLASS_NAMES_ARRAY"}
    line=${line//'$CLASS_NAMES'/"$CLASS_NAMES"}
    line=${line//'$CPPIA_DLL'/"$CPPIA_DLL"}
    line=${line//'$DEBUG_FLAG'/"$DEBUG_FLAG"}
    line=${line//'$CPPIA_OUT'/"$CPPIA_OUT"}
    printf '%s\n' "$line"
done < "$SDK_ABS/cppia.hxml" > "$GENERATED"

HAXE_STD=$(haxe_std_path)
CPPIA_SDK="$SDK_ABS"

#CPPIA subtitution
while IFS= read -r line || [[ -n $line ]]; do
    line=${line//'$HAXE_STD'/"$HAXE_STD"}
    line=${line//'$HAXE_STD'/"$HAXE_STD"}
    printf '%s\n' "$line"
done < "$HOST_CLASSES" > "$GEN_CPPIA_INFO"

echo "Building $OUTPUT from $SCRIPT_DIR"
echo "  ${#CLASSES[@]} class(es): ${CLASSES[*]}"

(cd "$SDK_ABS" && HAXELIB_PATH="$SDK_ABS" haxe "$GENERATED")

if [ "$REMOVE_CPPIA_TEMP_SDK" -eq 1 ]; then
	rm "$HOST_CLASSES"
	echo "Cleaned up temporary SDK"
fi

if [ ! -f "$OUTPUT" ]; then
	echo "haxe reported success but produced no $OUTPUT" >&2
	exit 1
fi

echo "Wrote $OUTPUT ($(wc -c < "$OUTPUT") bytes)"
