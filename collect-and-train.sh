#!/usr/bin/env bash
set -euo pipefail
set -x

TRAINING_TEXT_DIR=data/langdata/ftg
if [ ! -f "$TRAINING_TEXT_DIR" ]; then
    mkdir -p "$TRAINING_TEXT_DIR"
    node extract.ts "$TRAINING_TEXT_DIR"
    # https://stackoverflow.com/a/3741624
    find "$TRAINING_TEXT_DIR" -type f -path "*.poj" | while read -r f; do
        cat ~/git/kisaragi-rime-taigi/taigi-poj.syllables.dict.yaml | sed '/[:\.#-]/d;s/\t.*//' >>"$f"
    done
    parallel bunx @kemdict/kesi --to kip --input "{}" --output "{.}".kip ::: "$TRAINING_TEXT_DIR"/*.poj
    find "$TRAINING_TEXT_DIR" -type f -path "*.poj" | while read -r f; do
        cat "$f" "${f%.*}".kip >"${f%.*}".txt
    done
    find "$TRAINING_TEXT_DIR" -type f -path "*.poj" -delete
    find "$TRAINING_TEXT_DIR" -type f -path "*.kip" -delete
fi

GT_DIR=data/ftg-ground-truth
OUTPUT_DIR=data/ftg
rm -rf "$GT_DIR" "$OUTPUT_DIR"

# Generate the main thing first for more complete unicharset etc.
# We need more than just the trainedmodel files from tessdata.
# /usr/share/tessdata works for this.
uv run python src/tesstrain --linedata_only \
    --lang ftg \
    --langdata_dir data/langdata \
    --tessdata_dir /usr/share/tessdata \
    --training_text "$TRAINING_DIR"/ftg.training_text.all.txt \
    --output_dir "$GT_DIR"
# Prefer the segmented lstmf files
find "$GT_DIR" -path "*.lstmf" -delete
# Then generate the lstmf files for segments
find "$TRAINING_TEXT_DIR" -type f -path "*.txt" | while read -r f; do
    if [ "$(basename "$f")" == ftg.training_text.all.txt ]; then
        continue
    fi
    rm -rf data/tmp
    mkdir -p data/tmp
    uv run python src/tesstrain --linedata_only \
        --lang ftg \
        --langdata_dir data/langdata \
        --tessdata_dir /usr/share/tessdata \
        --training_text "$f" \
        --output_dir data/tmp
    find data/tmp -path "*.lstmf" -exec mv '{}' "$GT_DIR" ';'
done

mv "$GT_DIR"/ftg "$OUTPUT_DIR"
find "$GT_DIR" -path "*.lstmf" >"$OUTPUT_DIR"/all-lstmf
cp "$TRAINING_TEXT_DIR"/ftg.training_text.all.txt "$OUTPUT_DIR"/all-gt

make TESSDATA="data/tessdata" data/tessdata/eng.traineddata
make training MODEL_NAME=ftg START_MODEL=eng TESSDATA="data/tessdata"
make traineddata MODEL_NAME=ftg
