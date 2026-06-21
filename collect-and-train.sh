#!/usr/bin/env bash
set -euo pipefail

TRAINING_TEXT_DIR=data/langdata/ftg
GT_DIR=data/ftg-ground-truth
OUTPUT_DIR=data/ftg

# For shuffling lstmf listing
RANDOM_SEED=0

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
    download_one essay-taigi.txt 'https://github.com/kemdict/taigi-playground/raw/main/essay-taigi.txt'
    download_one yataigi-poj.syllables.dict.yaml 'https://github.com/kemdict/taigi-playground/raw/main/yataigi-poj.syllables.dict.yaml'
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
        # We must do splitting here, after combining the KIP conversion and the
        # syllables.
        node splitFile.ts "$TRAINING_TEXT_DIR"/ftg.training_text.all.txt \
            --outdir "$TRAINING_TEXT_DIR" \
            --base "ftg.training_text"
    fi
}

make_one_lstmf() {
    local f="$1"
    local short
    short="$(basename "$f" .txt | sed s/training_text.//)"
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
}; export -f make_one_lstmf

make_one_lstmf_from_gt() {
    local input="$1"
    local noext="$2"
    PYTHONIOENCODING=utf-8 $(PY_CMD) $(GENERATE_BOX_SCRIPT) -i "$input" -t "$noext".gt.txt > "$noext".box
    # Page segmentation mode, as defined in the Makefile.
    PSM=13
    tesseract "$1" "$2" --psm "$PSM" lstm.train
}; export -f make_one_lstmf_from_gt

make_split_lstmf() {
    if [ -n "$(find data/ftg-ground-truth -path "*.lstmf" -print -quit)" ]; then
        echo There are already lstmf files in "$GT_DIR". Skipping, assuming lstmf files are already made
        return
    fi
    echo "Creating lstmf files from existing gt/image pairs (real image samples)..."
    # We use parallel instead of Make here to get progress report.
    # We also use our own function instead of invoking Make per file because the
    # Makefile is written to always list ALL_FILES and will take a long time.
    find "$GT_DIR" '(' -path "*.png" -or "*.tif" ')' -print0 |
        parallel -0 --eta make_one_lstmf_from_gt '{}' '{.}' || true
    echo "Creating lstmf files from input training text (synthesized images)..."
    # Generate the lstmf files for each segment
    if [ ! -d data/ftg-parts ]; then
        # FIXME some of these calls may be failing?
        find "$TRAINING_TEXT_DIR" -type f -path "*.txt" -print0 |
            parallel -0 --eta make_one_lstmf || true
    fi
    echo Moving generated lstmf files to the right place...
    set -x
    # mkdir -p "$GT_DIR"

    # They all have the same basename, so add their directory names onto the
    # final name to avoid overwriting them.
    # And just in case, also use mv -n to not overwrite anything.
    # Note about the {= ... =} magic:
    # - {= ... =} in Parallel means replace input items with the result of
    #   running the Perl expression in between
    # - a sed-style s/from/to/ expression is a valid Perl expression that works
    #   for this purpose
    # - We are replacing "^.*\/([^\/]+)\/([^\/]*)" with "\1-\2", to turn
    #   "path/to/ftg.100/foo.lstmf" into "ftg.100-foo.lstmf".
    #   (slashes are escaped because a bare slash is part of the s/from/to/ syntax)
    #   In Elisp rx syntax this would be:
    #   (rx bol (* any) "/"
    #       (group (+ (not "/"))) "/"
    #       (group (* (not "/"))))
    mkdir -p "$GT_DIR" "$OUTPUT_DIR"
    find data/ftg-parts -path "*.lstmf" -print0 |
        parallel -0 mv -n '{}' "$GT_DIR"/'{= s/^.*\/([^\/]+)\/([^\/]*)/\1-\2/ =}'
    echo Writing OUTPUT_DIR/all-gt...
    cat "$TRAINING_TEXT_DIR"/ftg.training_text.all.txt \
        >"$OUTPUT_DIR"/all-gt
    for f in "$(find "$GT_DIR" -path "*.gt.txt")"; do
        cat "$f" >>"$OUTPUT_DIR"/all-gt
    done
    echo Writing OUTPUT_DIR/all-lstmf...
    find "$GT_DIR" -path "*.lstmf" \
        >"$OUTPUT_DIR"/all-lstmf
    echo Shuffling OUTPUT_DIR/all-lstmf...
    python shuffle.py "$RANDOM_SEED" "$OUTPUT_DIR"/all-lstmf
}

merge_our_unicharsets() {
    # We can probably also just rely on the Makefile instead, which takes
    # ALL_GT, runs unicharset_extractor on it, then merges it with the
    # unicharset of the START_MODEL.
    readarray files < <(find data/ftg-parts -path "*.unicharset")
    merge_unicharsets "${files[@]}" "$OUTPUT_DIR"/unicharset
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
make_split_lstmf
train
