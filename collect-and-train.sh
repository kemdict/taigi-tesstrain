#!/usr/bin/env bash
set -euo pipefail
set -x

if [ ! -f "data/ftg/ftg.training_text" ]; then
    node extract.ts >data/ftg/ftg.training_text
    cat ~/git/kisaragi-rime-taigi/taigi-poj.syllables.dict.yaml | sed '/[:\.#-]/d;s/\t.*//' >>data/ftg/ftg.training_text
    bunx @kemdict/kesi --to poj --input data/ftg/ftg.training_text --output data/ftg/ftg.training_text.poj
    bunx @kemdict/kesi --to kip --input data/ftg/ftg.training_text --output data/ftg/ftg.training_text.kip
    cat data/ftg/ftg.training_text.poj data/ftg/ftg.training_text.kip >data/ftg/ftg.training_text
fi
make TESSDATA="data/tessdata" data/tessdata/eng.traineddata
uv run python src/tesstrain --linedata_only --lang ftg --langdata_dir data --tessdata_dir data/tessdata --fontlist 'Liberation Serif' 'Noto Serif' 'Iosevka' 'Charis'
make training MODEL_NAME=ftg START_MODEL=eng TESSDATA="data/tessdata"
make traineddata MODEL_NAME=ftg
