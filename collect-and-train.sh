#!/usr/bin/env bash
set -euo pipefail

TRAINING_TEXT_DIR=data/langdata/ftg
GT_DIR=data/ftg-ground-truth
OUTPUT_DIR=data/ftg

download_one() {
    if [ -f "$1" ]; then return; fi
    echo "Downloading $1 from $2..."
    wget -O "$1" "$2"
}

download_data() {
    uv sync
    bun install

    make -j4 tesseract-langdata

    download_one pojbh.json 'https://github.com/Taiwanese-Corpus/Khin-hoan_2010_pojbh/raw/master/pojbh.json'
    download_one essay-taigi.txt 'https://github.com/kisaragi-hiu/kisaragi-rime-taigi/raw/main/essay-taigi.txt'
    download_one yataigi-poj.syllables.dict.yaml 'https://github.com/kisaragi-hiu/kisaragi-rime-taigi/raw/main/yataigi-poj.syllables.dict.yaml'
    mkdir -p data/tessdata/script
    download_one data/tessdata/eng.traineddata 'https://github.com/tesseract-ocr/tessdata_best/raw/main/eng.traineddata'
    download_one data/tessdata/script/Latin.traineddata 'https://github.com/tesseract-ocr/tessdata_best/raw/main/script/Latin.traineddata'
}

make_text() {
    if [ ! -f "$TRAINING_TEXT_DIR"/ftg.training_text.all.txt ]; then
        mkdir -p "$TRAINING_TEXT_DIR"
        echo Extracting training text...
        node extract.ts --bucket-size 0 "$TRAINING_TEXT_DIR"
        echo Copying syllables...
        cat yataigi-poj.syllables.dict.yaml |
            sed '/[:\.#-]/d;s/\t.*//' >>"$TRAINING_TEXT_DIR"/ftg.training_text.all.poj
        echo Converting POJ to KIP...
        parallel bunx @kemdict/kesi --to kip --input "{}" --output "{.}".kip ::: "$TRAINING_TEXT_DIR"/*.poj
        echo Combining POJ and KIP...
        find "$TRAINING_TEXT_DIR" -type f -path "*.poj" | while read -r f; do
            cat "$f" "${f%.*}".kip >"${f%.*}".txt
        done
        echo "Deleting intermediate (non-merged) POJ and KIP files..."
        find "$TRAINING_TEXT_DIR" -type f -path "*.poj" -delete
        find "$TRAINING_TEXT_DIR" -type f -path "*.kip" -delete
    fi
}


make_gt() {
    if [ -f "$OUTPUT_DIR/all-gt" ]; then return; fi
    echo Generating ground truth files from input text...
    mkdir -p "$GT_DIR" "$OUTPUT_DIR"
    uv run create_ground_truth -f "Charis,Dejavu Serif Italic,Dejavu Serif,Iosevka,Liberation Serif,Noto Sans,Noto Sans CJK TC,Noto Serif,Fira Sans Compressed Ultra-Condensed" \
        "$TRAINING_TEXT_DIR"/ftg.training_text.all.txt \
        "$GT_DIR"
    echo Writing OUTPUT_DIR/all-gt...
    cp "$TRAINING_TEXT_DIR"/ftg.training_text.all.txt "$OUTPUT_DIR"/all-gt
}

make_one_lstmf() {
    local image="$1"
    local noext="$2"
    if [ -f "$noext".lstmf ]; then return; fi
    # Copies of variables from the Makefile
    PSM=13
    # The Makefile logic for this variable is to use generate_wordstr_box.py if
    # LANG_TYPE is Indic or RTL, and generate_line_box.py otherwise (default).
    GENERATE_BOX_SCRIPT=generate_line_box.py
    PYTHONIOENCODING=utf-8 uv run python "$(GENERATE_BOX_SCRIPT)" -i "$image" -t "$noext".gt.txt > "$noext".box
    tesseract "$image" "$noext" --psm "$PSM" lstm.train
}; export -f make_one_lstmf

make_lstmf() {
    # We do this ourselves to use parallel instead of Make for this step.
    # generate lstmf files
    find "$GT_DIR" -path "*.tif" -print0 |
        parallel --eta -0 make_one_lstmf "{}" "{.}"
    find "$GT_DIR" -path "*.lstmf" > "$OUTPUT_DIR"/all-lstmf
    # Copied from Makefile
    RANDOM_SEED=0
    uv run python shuffle.py "$RANDOM_SEED" "$OUTPUT_DIR"/all-lstmf
}

train() {
    echo Starting training...
    set -x
    cat essay-taigi.txt |
        awk '{ print $2 "\t" $1 }' |
        sort -rn |
        awk '{ print $2 }' >"$OUTPUT_DIR"/ftg.wordlist

    make training MODEL_NAME=ftg START_MODEL=eng TESSDATA="data/tessdata"
    mv data/ftg.traineddata data/ftg-best.traineddata
    # Also generate the "fast" model (I think this is called quantization nowadays)
    local PROTO_MODEL=data/ftg/ftg.traineddata
    local LAST_CHECKPOINT=data/ftg/checkpoints/ftg_checkpoint
    lstmtraining \
        --stop_training \
        --continue_from "$LAST_CHECKPOINT" \
        --traineddata "$PROTO_MODEL" \
        --convert_to_int \
        --model_output data/ftg-fast.traineddata
}

download_data
make_text
make_gt
make_lstmf
train
