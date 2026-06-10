#!/usr/bin/env bash
set -euo pipefail
set -x

node extract.ts >data/ftg/ftg.training_text
cat ~/git/kisaragi-rime-taigi/taigi-poj.syllables.dict.yaml | sed '/[:\.#-]/d;s/\t.*//' >>data/ftg/ftg.training_text
bunx @kemdict/kesi --to poj --input data/ftg/ftg.training_text --output data/ftg/ftg.training_text.poj
bunx @kemdict/kesi --to kip --input data/ftg/ftg.training_text --output data/ftg/ftg.training_text.kip
cat data/ftg/ftg.training_text.poj data/ftg/ftg.training_text.kip >data/ftg/ftg.training_text
make training MODEL_NAME=ftg START_MODEL=eng
make traineddata MODEL_NAME=ftg
