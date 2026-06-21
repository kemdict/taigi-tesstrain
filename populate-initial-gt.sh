#!/usr/bin/env bash
if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
    echo "populate-initial-gt.sh

Run tesseract on images to get an initial ground truth text for later editing."
    exit
fi

set -euo pipefail

download_one() {
    if [ -f "$1" ]; then return; fi
    echo "Downloading $1 from $2..."
    wget -O "$1" "$2"
}

download_one data/ftg-best.traineddata "https://github.com/kemdict/taigi-tesstrain/releases/download/v0.1.4/ftg-best.traineddata"

find "data/ftg-ground-truth/" '(' -path "*.png" -or -path "*.tif" ')' | while read -r f; do
    if [ -f "${f%.*}".gt.txt ]; then
        continue
    fi
    echo "Creating ${f%.*}.gt.txt..."
    tesseract --tessdata-dir data -l ftg-best "$f" "${f%.*}".gt
done
