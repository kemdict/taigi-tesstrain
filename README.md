# taigi-tesstrain

An attempt to make a Tesseract model for [Taiwanese Taigi](https://en.wikipedia.org/wiki/Taiwanese_Hokkien) in Latin script (both POJ and TL).

The language code chosen is [`ftg`](https://iso639-3.sil.org/request/2021-044); this is a bit premature, but if that request is rejected then renaming to `nan` is trivial too.

This training uses synthetic images, fine tuned on top of the English model.

## Using the trained model

Put the ftg.traineddata file in a folder (for example "my-tessdata-dir"), then call

```sh
tesseract --tessdata-dir "my-tessdata-dir" -l ftg input-image.png output-basename
```

## Future work

wordlist? other config stuff? upstreaming?

## Reproducing the training

### Required programs

I'm running this on Linux. This will fail on macOS because I assume one location where Tesseract is installed. On Windows try WSL.

- `bash`, `make` (4.2+), `wget`, `find`, `unzip` for the original Makefile
- `tesseract` (5.3+): As with the original tesstrain:
  > You will need a recent version (>= 5.3) of tesseract built with the training tools and matching leptonica bindings.
- `node` for the `extract.ts` glue code
- `bun` for running my `@kemdict/kesi` port of [i3thuan5/KeSi](https://github.com/i3thuan5/KeSi)
  - Sorry, simplifying my dependencies is currently out of scope as I figure things out
  - I'm using `bunx` because I haven't set up a package.json yet.
- `uv` and `python` for running the tesstrain module.
  - I've pinned Python to 3.14, which should be easy to get with `uv`.
  - A `uv sync` should be run to install Python dependencies.
- `bash`, `parallel`, `sed` for the `collect-and-train.sh` entry point

### Data

`extract.ts` takes Taigi text from the corpus and assembles them in the right place. The corpus is currently taken from [the 台灣白話字文獻館 mirror](https://github.com/Taiwanese-Corpus/Khin-hoan_2010_pojbh). You will have to download [`pojbh.json`](https://github.com/Taiwanese-Corpus/Khin-hoan_2010_pojbh/blob/master/pojbh.json) to `./pojbh.json` first.

```sh
wget -O ./pojbh.json "https://github.com/Taiwanese-Corpus/Khin-hoan_2010_pojbh/raw/master/pojbh.json"
```

`collect-and-train.sh` then also collects a list of valid POJ / TL syllables from [another project of mine](https://github.com/kisaragi-hiu/kisaragi-rime-taigi). (This is now done automatically.)

Tesseract also wants some language / script data to be present. Download langdata (which includes unicharset files for different scripts) with:

```sh
make tesseract-langdata
```

The “best” (float, not quantized to int) traineddata for Latin (script) and English (language) are also needed, as these are the base models that I'm using.

```sh
mkdir -p data/tessdata
wget -O data/tessdata/eng.traineddata 'https://github.com/tesseract-ocr/tessdata_best/raw/main/eng.traineddata'
wget -O data/tessdata/script/Latin.traineddata 'https://github.com/tesseract-ocr/tessdata_best/raw/main/script/Latin.traineddata'
```

At the same time, certain files from

## Training

Run `bash collect-and-train.sh`. If I did not screw up this should finish with a usable model at `data/ftg.trainedmodel` after about 2 hours.

## License

Software is provided under the terms of the `Apache 2.0` license, as with original tesstrain.
