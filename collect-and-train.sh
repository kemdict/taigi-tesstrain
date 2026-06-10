#!/usr/bin/env bash
set -euo pipefail
set -x

TESTING=true
TRAINING_TEXT_DIR=data/langdata/ftg
if [ ! -f "$TRAINING_TEXT_DIR/ftg.training_text" ]; then
    mkdir -p "$TRAINING_TEXT_DIR"
    node extract.ts >"$TRAINING_TEXT_DIR"/ftg.training_text.poj
    cat ~/git/kisaragi-rime-taigi/taigi-poj.syllables.dict.yaml | sed '/[:\.#-]/d;s/\t.*//' >>"$TRAINING_TEXT_DIR"/ftg.training_text.poj
    bunx @kemdict/kesi --to kip --input "$TRAINING_TEXT_DIR"/ftg.training_text.poj --output "$TRAINING_TEXT_DIR"/ftg.training_text.kip
    if [ -n "$TESTING" ]; then
        cat "$TRAINING_TEXT_DIR"/ftg.training_text.poj "$TRAINING_TEXT_DIR"/ftg.training_text.kip | head -n 1000 >"$TRAINING_TEXT_DIR"/ftg.training_text
    else
        cat "$TRAINING_TEXT_DIR"/ftg.training_text.poj "$TRAINING_TEXT_DIR"/ftg.training_text.kip >"$TRAINING_TEXT_DIR"/ftg.training_text
    fi
fi

GT_DIR=data/ftg-ground-truth
OUTPUT_DIR=data/ftg
rm -rf "$GT_DIR" "$OUTPUT_DIR"

# We need more than just the trainedmodel files from tessdata. The system
# install works for this.
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
