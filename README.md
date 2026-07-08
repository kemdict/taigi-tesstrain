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

### Fonts

I'm training on these fonts currently, which need to be installed in /usr/share/fonts.

```python
# see src/tesstrain/language_specific.py#L153
'Charis', 'Dejavu Serif Italic', 'Dejavu Serif', 'Iosevka', 'Liberation Serif', 'Noto Sans', 'Noto Sans CJK TC', 'Noto Serif', 'Roboto Condensed, Condensed',
```

### Input data

None of the data here needs to be downloaded manually, I try to make sure (apart from installing packages) the only thing that needs to be run is `collect-and-train.sh`.

I grab a list of valid POJ / TL syllables and the wordlist from [another project of mine](https://github.com/kemdict/taigi-playground). The syllables list ultimately comes from the definition of POJ/TL which I copied from Wikipedia; and the wordlist is from a bunch of dictionaries aggregated in Kemdict then ordered by frequency by checking with a private corpus as well as `pojbh.json`.

There are two kinds of input training text/images:

- Images synthesized with `text2image` from an corpus of input text. The corpus is currently taken from [the 台灣白話字文獻館 mirror](https://github.com/Taiwanese-Corpus/Khin-hoan_2010_pojbh), from its `pojbh.json` file.
- Pairs of real scans and manually edited ground truth texts. These are added to the repository in data/ftg-ground-truth.
  - Some of these scans are single-line image + ground truth text pairs. An lstmf file would be generated from these files and go into training.
    The ground truth texts are usually first created by using `utils.ts populate-initial-gt` to recognize the images with a previous model, then manually edited. I might also manually type in the whole thing.
  - Some of these scans are multi-line image + multi-line box files + ground truth texts. These images are annotated in VGG Image Annotator, then exported to JSON. The JSON files are then, combining with the ground truth texts, converted into box files with `utils.ts vgg-convert-to-boxes`.

### Training

Finally run `bash collect-and-train.sh`. If I did not screw up this should finish with a usable model at `data/ftg.trainedmodel` after about 2 hours.

## Helper scripts

This is my attempt to document the scripts in here, both inherited from upstream tesstrain and also our own.

Automated:

- Makefile: upstream tesstrain's entry point that collect-and-train.sh calls into.
  - `generate_eval_train.py`: Take the intermediary all-lstmf listing file and split it into a training set and an eval set.
  - `generate_line_box.py`: Generate a box file from an image and its ground truth text. The image (and the text file) can only contain one text line.
  - `generate_wordstr_box.py`: Box file generation from image + ground truth text, used for Indic and RTL scripts (kept here because I don't want to modify the Makefile).
  - `plot_cer.py, plot_log.py`: Used for plotting training performance
  - `shuffle.py`: Shuffle lines in an input text file. Used to shuffle which lstmf files go into the training set and which go into the eval set.
- `collect-and-train.sh`: Main entry point for training.
  - `extract.ts`: Extract synthesis ground truth from pojbh.json
  - `splitFile.ts`: Split lines of a text file into their own files. Used for the line-based splitting method. Will be removed since that method does not help.

Random maybe-useful scripts:

- `generate_gt_from_box.py`: Extract the text from a box file. Not used for taigi-tesstrain's workflows.
- `normalize.py`: Unicode-normalize a text file. Unused but seems useful to keep around.

Some tools are `utils.ts` subcommands:
- `utils.ts image-split-lines`: Use tesseract's line detection to split an image into multiple images, each representing one line.
- `utils.ts populate-initial-gt`: Take image files that do not have ground truth text, and use tesseract (and an existing model) to recognize its text, so we can use a less perfect model to assist with manual recognition.
- `utils.ts vgg-convert-to-boxes`: Convert annotations in JSON files exported from VGG Image Annotator into box files.

## Changelog

- 0.1.2: Actually apply the new wordlist (we weren't putting punc file in the right place).
- 0.1.1: add wordlist and punctuations. This seems to have zero effect on the output...
  - Turns out this was a failed run that got masked as a successful run because I had leftover files.
- 0.1.0: first usable model

## License

Software is provided under the terms of the `Apache 2.0` license, as with original tesstrain.
