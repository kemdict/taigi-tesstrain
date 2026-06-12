#!/usr/bin/env bash
set -euo pipefail

TRAINING_TEXT_DIR=data/langdata/ftg
GT_DIR=data/ftg-ground-truth
OUTPUT_DIR=data/ftg

make_text() {
    if [ ! -d "$TRAINING_TEXT_DIR" ]; then
        mkdir -p "$TRAINING_TEXT_DIR"
        node extract.ts --bucket-size 10 "$TRAINING_TEXT_DIR"
        curl -L https://github.com/kisaragi-hiu/kisaragi-rime-taigi/raw/main/yataigi-poj.syllables.dict.yaml |
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
    if [ -d "$GT_DIR" ] && [ -d "$OUTPUT_DIR" ]; then
        echo "$GT_DIR" and "$OUTPUT_DIR" already present, assuming split lstmf files are already made
        return
    fi
    # Generate the lstmf files for each segments
    if [ ! -d data/ftg-parts ]; then
        find "$TRAINING_TEXT_DIR" -type f -path "*.txt" -print0 |
            parallel -0 --eta make_one_lstmf
    fi
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
    find "$GT_DIR" -path "*.lstmf" >"$OUTPUT_DIR"/all-lstmf
    cat "$TRAINING_TEXT_DIR"/ftg.training_text.all.txt \
        "$TRAINING_TEXT_DIR"/ftg.training_text.syllables.txt \
        >"$OUTPUT_DIR"/all-gt
}

merge_our_unicharsets() {
    # We can probably also just rely on the Makefile instead, which takes
    # ALL_GT, runs unicharset_extractor on it, then merges it with the
    # unicharset of the START_MODEL.
    readarray files < <(find data/ftg-parts -path "*.unicharset")
    merge_unicharsets "${files[@]}" "$OUTPUT_DIR"/unicharset
}

train() {
    set -x
    make TESSDATA="data/tessdata" data/tessdata/eng.traineddata
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

make_text
make_split_lstmf
train
