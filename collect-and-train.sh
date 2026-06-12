#!/usr/bin/env bash
set -euo pipefail
set -x

TRAINING_TEXT_DIR=data/langdata/ftg
GT_DIR=data/ftg-ground-truth
OUTPUT_DIR=data/ftg

make_text() {
    if [ ! -d "$TRAINING_TEXT_DIR" ]; then
        mkdir -p "$TRAINING_TEXT_DIR"
        node extract.ts --bucket-size 10 "$TRAINING_TEXT_DIR"
        cat ~/git/kisaragi-rime-taigi/taigi-poj.syllables.dict.yaml |
            sed '/[:\.#-]/d;s/\t.*//' >"$TRAINING_TEXT_DIR"/ftg.training_text.syllables.poj
        parallel bunx @kemdict/kesi --to kip --input "{}" --output "{.}".kip ::: "$TRAINING_TEXT_DIR"/*.poj
        find "$TRAINING_TEXT_DIR" -type f -path "*.poj" | while read -r f; do
            cat "$f" "${f%.*}".kip >"${f%.*}".txt
        done
        find "$TRAINING_TEXT_DIR" -type f -path "*.poj" -delete
        find "$TRAINING_TEXT_DIR" -type f -path "*.kip" -delete
    fi
}

make_one_lstmf() {
    local f="$1"
    local short="$(basename "$f" .txt | sed s/training_text.//)"
    if [ "$short" == ftg.all ]; then
        return
    fi
    mkdir -p data/ftg-parts/
    uv run python src/tesstrain --linedata_only \
        --lang ftg \
        --langdata_dir data/langdata \
        --tessdata_dir /usr/share/tessdata \
        --training_text "$f" \
        --output_dir data/ftg-parts/"$short"
}
export -f make_one_lstmf

make_full_lstmf() {
    # Generate the main thing first for more complete unicharset etc.
    # This takes at least 24 hours!
    # We need more than just the trainedmodel files from tessdata.
    # /usr/share/tessdata works for this.
    uv run python src/tesstrain --linedata_only \
        --lang ftg \
        --langdata_dir data/langdata \
        --tessdata_dir /usr/share/tessdata \
        --training_text "$TRAINING_TEXT_DIR"/ftg.training_text.all.txt \
        --output_dir "$GT_DIR"
}

make_split_lstmf() {
    # Generate the lstmf files for each segments
    find "$TRAINING_TEXT_DIR" -type f -path "*.txt" -print0 | parallel -0 --eta make_one_lstmf
    # mkdir -p "$GT_DIR"
    # find data/ftg-parts -path "*.lstmf" -exec mv '{}' "$GT_DIR" ';'
    # mv "$GT_DIR"/ftg "$OUTPUT_DIR"
    # find "$GT_DIR" -path "*.lstmf" >"$OUTPUT_DIR"/all-lstmf
    # cp "$TRAINING_TEXT_DIR"/ftg.training_text.all.txt "$OUTPUT_DIR"/all-gt
}

train() {
    make TESSDATA="data/tessdata" data/tessdata/eng.traineddata
    make training MODEL_NAME=ftg START_MODEL=eng TESSDATA="data/tessdata"
    make traineddata MODEL_NAME=ftg
}

make_text
make_split_lstmf
