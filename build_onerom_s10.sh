#!/bin/bash
#
# Build OneKernel (ExtremeKRNL base + KernelSU-Next legacy) for OneROM
# and repack it with the known-good OneROM 9.0.1.0 boot.img ramdisk/header.
#
# Usage: ./build_onerom_s10.sh [-m beyond1lte] [--install /path/to/OneROM]
#
set -e

MODEL=beyond1lte
INSTALL_DIR=""
REF_BOOT="${REF_BOOT:-$HOME/kernel_work/boot_9010.img}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -m|--model) MODEL="$2"; shift 2 ;;
        --install) INSTALL_DIR="$2"; shift 2 ;;
        *) echo "Usage: $0 [-m model] [--install /path/to/OneROM]"; exit 1 ;;
    esac
done

cd "$(dirname "$0")"
SRC="$PWD"
TOOLS="${ONEROM_TOOLS:-$HOME/OneROM_17/out/tools/bin}"

[ -f "$REF_BOOT" ] || { echo "Reference boot.img not found: $REF_BOOT"; exit 1; }
[ -d KernelSU-Next/.git ] || { echo "KernelSU-Next is not a git repo (version detection would fail)"; exit 1; }

echo "== KernelSU-Next: $(git -C KernelSU-Next describe --tags) (ksuver $((30000 + $(git -C KernelSU-Next rev-list --count HEAD) + 289)))"

# Build Image + dtb + dtbo via upstream build.sh (applies GPU tables, KSU config)
EXTRA_CONFIGS="onerom.config" ./build.sh -m "$MODEL" -k y

OUT="$SRC/build/out/$MODEL"
RD="$OUT/onerom"
rm -rf "$RD" && mkdir -p "$RD/ref"

# Repack with reference ramdisk + exact header args
"$TOOLS/unpack_bootimg" --boot_img "$REF_BOOT" --out "$RD/ref" --format mkbootimg > "$RD/ref/args"
ARGS="$(sed "s|--kernel [^ ]*|--kernel $OUT/Image|" "$RD/ref/args")"
eval "\"$TOOLS/mkbootimg\" $ARGS -o \"$RD/boot.img\""
cp "$OUT/dtb.img" "$OUT/dtbo.img" "$RD/"

( cd "$RD" && sha256sum boot.img dtb.img dtbo.img > SHA256SUMS )
echo "== Output:"; ls -la "$RD"
strings "$RD/boot.img" | grep -m1 "Linux version"

if [ -n "$INSTALL_DIR" ]; then
    K="$INSTALL_DIR/target/$MODEL/kernel"
    cp "$RD/boot.img" "$RD/dtb.img" "$RD/dtbo.img" "$RD/SHA256SUMS" "$K/"
    echo "== Installed into $K"
fi
