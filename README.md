# Kedar - MSA Visualizer

`msa_visualizer.py` performs nucleotide multiple sequence alignment (MSA), highlights polymorphic loci with base-specific colors, and reports summary polymorphism metrics.

## Features

- Handles FASTA and gzipped FASTA (`.fasta.gz` / `.fa.gz`)
- Runs external MSA tools (`FAMSA` or `MAFFT`) via subprocess
- Color-coded terminal output (A/T/G/C shown with distinct colors)
- HTML export with CSS coloring for aligned sequences
- Polymorphism statistics:
  - polymorphic/conserved site counts
  - mean conservation
  - mean entropy
  - transition/transversion counts and ratio
- Optional SNP-pattern clustering using `scikit-learn` KMeans
- Memory-conscious streaming for FASTA input handling

## Requirements

Python 3.10+ and one aligner installed in `PATH`:

- [FAMSA](https://github.com/refresh-bio/FAMSA), or
- [MAFFT](https://mafft.cbrc.jp/alignment/software/)

Install Python dependencies:

```bash
pip install -r requirements.txt
```

## CLI Usage

```bash
python msa_visualizer.py INPUT_FASTA [options]
```

### Common options

- `--aligned-input` : treat input as already aligned (skip MSA run)
- `--aligner {auto,famsa,mafft}` : alignment tool selection (default: `auto`)
- `--threads N` : aligner thread count
- `--aligned-out PATH` : aligned FASTA output path
- `--show-all-columns` : render all alignment columns (default is polymorphic loci focus)
- `--max-terminal-seqs N` : cap terminal rows for large datasets
- `--html-out PATH` : write HTML visualization
- `--cluster-k K` : optional KMeans clustering on SNP pattern vectors
- `--check-tools` : verify aligner availability and exit

## Examples

Check aligners:

```bash
python msa_visualizer.py data/sample_aligned.fasta --check-tools
```

Use pre-aligned FASTA and export HTML:

```bash
python msa_visualizer.py data/sample_aligned.fasta \
  --aligned-input \
  --html-out output.html
```

Run alignment first (auto-detect FAMSA/MAFFT):

```bash
python msa_visualizer.py input_sequences.fasta \
  --aligner auto \
  --threads 8 \
  --aligned-out aligned.fasta \
  --html-out aligned.html
```

Optional SNP clustering:

```bash
python msa_visualizer.py aligned.fasta --aligned-input --cluster-k 3
```

## Test data

Sample aligned FASTA is provided at:

- `data/sample_aligned.fasta`

## Output notes

- Terminal coloring uses Rich style mapping:
  - A = green
  - T = red
  - G = yellow
  - C = blue
- HTML output uses matching color mapping with dimmed non-polymorphic positions (unless `--show-all-columns` is used).
