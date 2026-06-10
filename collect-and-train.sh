#!/usr/bin/env bash
set -euo pipefail
set -x

TRAINING_TEXT_DIR=data/langdata/ftg
if [ ! -f "$TRAINING_TEXT_DIR" ]; then
    mkdir -p "$TRAINING_TEXT_DIR"
    node extract.ts "$TRAINING_TEXT_DIR"
    set +x
    # https://stackoverflow.com/a/3741624
    find "$TRAINING_TEXT_DIR" -type f -path "*.poj" | while read -r f; do
        cat ~/git/kisaragi-rime-taigi/taigi-poj.syllables.dict.yaml | sed '/[:\.#-]/d;s/\t.*//' >>"$f"
    done
    set -x
    parallel bunx @kemdict/kesi --to kip --input "{}" --output "{.}".kip ::: "$TRAINING_TEXT_DIR"/*.poj
fi

GT_DIR=data/ftg-ground-truth
OUTPUT_DIR=data/ftg
rm -rf "$GT_DIR" "$OUTPUT_DIR"

# We need more than just the trainedmodel files from tessdata.
# /usr/share/tessdata works for this.
uv run python src/tesstrain --linedata_only \
    --lang ftg \
    --langdata_dir data/langdata \
    --tessdata_dir /usr/share/tessdata \
    --output_dir "$GT_DIR"
mv "$GT_DIR"/ftg "$OUTPUT_DIR"
find "$GT_DIR" -path "*.lstmf" >"$OUTPUT_DIR"/all-lstmf
cp "$TRAINING_TEXT_DIR"/ftg.training_text "$OUTPUT_DIR"/all-gt

make TESSDATA="data/tessdata" data/tessdata/eng.traineddata
make training MODEL_NAME=ftg START_MODEL=eng TESSDATA="data/tessdata"
make traineddata MODEL_NAME=ftg
