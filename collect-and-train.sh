#!/usr/bin/env bash
set -euo pipefail
set -x

DIR=data/langdata/ftg
if [ ! -f "$DIR/ftg.training_text" ]; then
    mkdir -p "$DIR"
    node extract.ts >"$DIR"/ftg.training_text.poj
    cat ~/git/kisaragi-rime-taigi/taigi-poj.syllables.dict.yaml | sed '/[:\.#-]/d;s/\t.*//' >>"$DIR"/ftg.training_text.poj
    bunx @kemdict/kesi --to kip --input "$DIR"/ftg.training_text.poj --output "$DIR"/ftg.training_text.kip
    cat "$DIR"/ftg.training_text.poj "$DIR"/ftg.training_text.kip >"$DIR"/ftg.training_text
fi
make TESSDATA="data/tessdata" data/tessdata/eng.traineddata
uv run python src/tesstrain --linedata_only \
    --lang ftg \
    --langdata_dir data/langdata \
    --tessdata_dir data/tessdata \
    --output_dir data/ftg
make training MODEL_NAME=ftg START_MODEL=eng TESSDATA="data/tessdata"
make traineddata MODEL_NAME=ftg
