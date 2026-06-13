# taigi-tesstrain

An attempt to make a Tesseract model for [Taiwanese Taigi](https://en.wikipedia.org/wiki/Taiwanese_Hokkien) in Latin script (both POJ and TL).

The language code chosen is [`ftg`](https://iso639-3.sil.org/request/2021-044); this is a bit premature, but if that request is rejected then renaming to `nan` is trivial too.

This training uses synthetic images, fine tuned on top of the English model.

## Using the trained model

Pick ftg-best.traineddata or ftg-fast.traineddata, then download it into a folder and rename it as `ftg.traineddata`.

("best" is like [tessdata_best](https://github.com/tesseract-ocr/tessdata_best): float models that can used for finetuning; "fast" is like [tessdata_fast](https://github.com/tesseract-ocr/tessdata_fast): int models that are also made smaller.)

Then, if the folder you put it into is called `my-tessdata`, run:

```sh
tesseract --tessdata-dir "my-tessdata" -l ftg input-image.png output-basename
```

## Future work

other config stuff? upstreaming?

## Reproducing the training

### Required programs

I'm running this on Linux. This will fail on macOS because I assume one location where Tesseract is installed. On Windows try WSL.

- `bash`, `make` (4.2+), `wget`, `find`, `unzip` for the original Makefile
- `tesseract` (5.3+): As with the original tesstrain:
  > You will need a recent version (>= 5.3) of tesseract built with the training tools and matching leptonica bindings.
- `node` or `bun` for the `extract.ts` glue code
- `bun` for running my `@kemdict/kesi` port of [i3thuan5/KeSi](https://github.com/i3thuan5/KeSi)
  - A `bun install` to install JS dependencies (just `@kemdict/kesi`) is advisable, though `collect-and-train.sh` does this automatically.
- `uv` and `python` for running the tesstrain module.
  - I've pinned Python to 3.14, which should be easy to get with `uv`.
  - A `uv sync` to install Python dependencies is advisable, though `collect-and-train.sh` also does this automatically.
- `bash`, `parallel`, `sed` for the `collect-and-train.sh` entry point

### Data

`extract.ts` takes Taigi text from the corpus and assembles them in the right place. The corpus is currently taken from [the 台灣白話字文獻館 mirror](https://github.com/Taiwanese-Corpus/Khin-hoan_2010_pojbh). You will have to download [`pojbh.json`](https://github.com/Taiwanese-Corpus/Khin-hoan_2010_pojbh/blob/master/pojbh.json) to `./pojbh.json` first. (This is now automatically done in `collect-and-train.sh`.)

I grab a list of valid POJ / TL syllables and the wordlist from [another project of mine](https://github.com/kisaragi-hiu/kisaragi-rime-taigi), which still needs documentation. (The syllables list ultimately comes from the definition of POJ/TL which I copied from Wikipedia; and the wordlist is from a bunch of dictionaries aggregated in Kemdict then ordered by frequency by checking with a private corpus as well as `pojbh.json`.) (These are also downloaded automatically in `collect-and-train.sh`.)

Tesseract also wants some language / script data to be present. Download langdata (which includes unicharset files for different scripts) with:

```sh
make tesseract-langdata
```

The “best” (float, not quantized to int) traineddata for Latin (script) and English (language) are also needed, as these are the base models that I'm using. This is now downloaded automatically in `collect-and-train.sh`.

### Training

Finally run `bash collect-and-train.sh`. If I did not screw up this should finish with a usable model at `data/ftg.trainedmodel` after about 2 hours.

## Changelog

- 0.1.1: add wordlist and punctuations. This seems to have zero effect on the output...
- 0.1.0: first usable model

## License

Software is provided under the terms of the `Apache 2.0` license, as with original tesstrain.
