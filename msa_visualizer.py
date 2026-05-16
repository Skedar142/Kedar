#!/usr/bin/env python3
"""MSA visualizer for nucleotide polymorphisms.

Features:
- Handles FASTA and FASTA.GZ input
- Runs external aligners (FAMSA or MAFFT)
- Detects polymorphic loci
- Color-coded terminal and HTML visualization
- Basic polymorphism statistics
- Optional SNP clustering (scikit-learn)
"""

from __future__ import annotations

import argparse
import gzip
import html
import math
import os
import shutil
import subprocess
import sys
import tempfile
from collections import Counter
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Iterator, Sequence

from Bio import AlignIO, SeqIO
from Bio.Align import MultipleSeqAlignment
from rich.console import Console
from rich.progress import track
from rich.table import Table
from rich.text import Text


NUCLEOTIDE_STYLES = {
    "A": "green",
    "T": "red",
    "G": "yellow",
    "C": "blue",
    "N": "bright_black",
    "-": "dim",
}

HTML_COLORS = {
    "A": "#2e7d32",
    "T": "#c62828",
    "G": "#ef6c00",
    "C": "#1565c0",
    "N": "#616161",
    "-": "#9e9e9e",
}

TRANSITIONS = {("A", "G"), ("G", "A"), ("C", "T"), ("T", "C")}


@dataclass
class AlignmentStats:
    """Summary statistics for aligned nucleotide sequences."""

    sequence_count: int
    alignment_length: int
    polymorphic_sites: int
    conserved_sites: int
    polymorphic_fraction: float
    mean_conservation: float
    mean_entropy: float
    transition_count: int
    transversion_count: int
    ti_tv_ratio: float | None


def open_text_auto(path: str | Path):
    """Open plain text or gzip-compressed text file."""
    path = str(path)
    return gzip.open(path, "rt", encoding="utf-8") if path.endswith(".gz") else open(path, "rt", encoding="utf-8")


def tool_path(tool: str) -> str | None:
    """Return executable path for tool if available in PATH."""
    return shutil.which(tool)


def check_alignment_tools() -> dict[str, str | None]:
    """Check availability of supported aligners."""
    return {"famsa": tool_path("famsa"), "mafft": tool_path("mafft")}


def choose_aligner(requested: str) -> str:
    """Resolve aligner choice from CLI option."""
    tools = check_alignment_tools()
    if requested in tools:
        if not tools[requested]:
            raise RuntimeError(f"Requested aligner '{requested}' is not installed or not in PATH.")
        return requested
    if tools["famsa"]:
        return "famsa"
    if tools["mafft"]:
        return "mafft"
    raise RuntimeError("No aligner found. Install FAMSA or MAFFT and ensure it is in PATH.")


def stream_fasta_records(path: str | Path) -> Iterator:
    """Yield FASTA records from regular or gzipped file."""
    with open_text_auto(path) as handle:
        yield from SeqIO.parse(handle, "fasta")


def count_fasta_sequences(path: str | Path) -> int:
    """Count FASTA records using streaming parser."""
    return sum(1 for _ in stream_fasta_records(path))


def prepare_input_fasta(path: str | Path, tmp_dir: str | Path) -> tuple[str, str | None]:
    """Return FASTA path usable by aligners; decompress .gz input to temporary FASTA."""
    source = str(path)
    if not source.endswith(".gz"):
        return source, None

    temp_fasta = Path(tmp_dir) / "input.decompressed.fasta"
    with open_text_auto(source) as in_handle, open(temp_fasta, "wt", encoding="utf-8") as out_handle:
        for record in SeqIO.parse(in_handle, "fasta"):
            SeqIO.write(record, out_handle, "fasta")
    return str(temp_fasta), str(temp_fasta)


def run_msa(input_fasta: str, output_fasta: str, aligner: str, threads: int = 1) -> None:
    """Run MSA with FAMSA or MAFFT and write aligned FASTA output."""
    aligner = choose_aligner(aligner)
    with tempfile.TemporaryDirectory(prefix="msa_vis_") as tmp_dir:
        align_input, _tmp_path = prepare_input_fasta(input_fasta, tmp_dir)

        if aligner == "famsa":
            cmd = ["famsa", "-t", str(threads), align_input, output_fasta]
            proc = subprocess.run(cmd, capture_output=True, text=True)
        else:
            cmd = ["mafft", "--thread", str(threads), "--auto", align_input]
            with open(output_fasta, "wt", encoding="utf-8") as out_handle:
                proc = subprocess.run(cmd, stdout=out_handle, stderr=subprocess.PIPE, text=True)

    if proc.returncode != 0:
        raise RuntimeError(f"Alignment failed with {aligner}:\n{proc.stderr.strip()}")


def read_alignment(aligned_fasta: str | Path) -> MultipleSeqAlignment:
    """Read aligned FASTA as MultipleSeqAlignment object."""
    with open_text_auto(aligned_fasta) as handle:
        alignment = AlignIO.read(handle, "fasta")
    if len(alignment) == 0:
        raise ValueError("Alignment has no sequences.")
    lengths = {len(rec.seq) for rec in alignment}
    if len(lengths) != 1:
        raise ValueError("Input does not appear aligned: sequence lengths differ.")
    return alignment


def polymorphic_positions(alignment: MultipleSeqAlignment) -> list[int]:
    """Return 0-based positions with >1 canonical nucleotide (ignores N and gaps)."""
    poly = []
    for idx in range(alignment.get_alignment_length()):
        counts = Counter(str(rec.seq[idx]).upper() for rec in alignment)
        canonical = {b for b, c in counts.items() if c > 0 and b in {"A", "T", "G", "C"}}
        if len(canonical) > 1:
            poly.append(idx)
    return poly


def _column_entropy(counts: Counter, n: int) -> float:
    """Calculate Shannon entropy for a column over A/T/G/C/-/N symbols."""
    entropy = 0.0
    for value in counts.values():
        if value == 0:
            continue
        p = value / n
        entropy -= p * math.log2(p)
    return entropy


def calculate_stats(alignment: MultipleSeqAlignment, poly_sites: Sequence[int]) -> AlignmentStats:
    """Calculate conservation, entropy, and Ti/Tv metrics."""
    n = len(alignment)
    m = alignment.get_alignment_length()

    conservation_values: list[float] = []
    entropy_values: list[float] = []
    transition_count = 0
    transversion_count = 0

    for idx in range(m):
        counts = Counter(str(rec.seq[idx]).upper() for rec in alignment)
        most_common = counts.most_common(1)[0][1]
        conservation_values.append(most_common / n)
        entropy_values.append(_column_entropy(counts, n))

        if idx in poly_sites:
            canonical = [b for b in counts if b in {"A", "T", "G", "C"}]
            canonical.sort(key=lambda b: counts[b], reverse=True)
            if len(canonical) >= 2:
                pair = (canonical[0], canonical[1])
                if pair in TRANSITIONS:
                    transition_count += 1
                else:
                    transversion_count += 1

    polymorphic_count = len(poly_sites)
    conserved_count = m - polymorphic_count
    ratio = (transition_count / transversion_count) if transversion_count else None

    return AlignmentStats(
        sequence_count=n,
        alignment_length=m,
        polymorphic_sites=polymorphic_count,
        conserved_sites=conserved_count,
        polymorphic_fraction=(polymorphic_count / m if m else 0.0),
        mean_conservation=(sum(conservation_values) / m if m else 0.0),
        mean_entropy=(sum(entropy_values) / m if m else 0.0),
        transition_count=transition_count,
        transversion_count=transversion_count,
        ti_tv_ratio=ratio,
    )


def sequence_vector_for_poly_sites(alignment: MultipleSeqAlignment, poly_sites: Sequence[int]) -> list[list[int]]:
    """Encode polymorphic positions into integer vectors for clustering."""
    mapping = {"A": 0, "T": 1, "G": 2, "C": 3, "N": 4, "-": 5}
    vectors: list[list[int]] = []
    for rec in alignment:
        vectors.append([mapping.get(str(rec.seq[pos]).upper(), 4) for pos in poly_sites])
    return vectors


def cluster_snps(alignment: MultipleSeqAlignment, poly_sites: Sequence[int], k: int) -> list[tuple[str, int]]:
    """Cluster sequences by SNP pattern using KMeans."""
    if not poly_sites:
        return [(rec.id, 0) for rec in alignment]

    try:
        from sklearn.cluster import KMeans
    except Exception as exc:
        raise RuntimeError("scikit-learn is required for clustering. Install from requirements.txt") from exc

    vectors = sequence_vector_for_poly_sites(alignment, poly_sites)
    model = KMeans(n_clusters=k, n_init=10, random_state=42)
    labels = model.fit_predict(vectors)
    return [(rec.id, int(label)) for rec, label in zip(alignment, labels)]


def render_sequence_text(sequence: str, highlight: set[int], dim_non_poly: bool) -> Text:
    """Render one sequence as Rich Text with nucleotide colors."""
    text = Text()
    for i, base in enumerate(sequence):
        b = base.upper()
        style = NUCLEOTIDE_STYLES.get(b, "white")
        if dim_non_poly and i not in highlight:
            style = "dim"
        text.append(base, style=style)
    return text


def render_terminal(
    alignment: MultipleSeqAlignment,
    poly_sites: Sequence[int],
    show_all_columns: bool,
    max_sequences: int,
    console: Console,
) -> None:
    """Render alignment in terminal with color-coded nucleotides."""
    highlight = set(poly_sites)
    table = Table(title="MSA Polymorphism View", show_lines=False)
    table.add_column("Sequence", style="bold", no_wrap=True)
    table.add_column("Aligned Bases", overflow="fold")

    rows_shown = 0
    for rec in alignment:
        if rows_shown >= max_sequences:
            break
        seq = str(rec.seq)
        if not show_all_columns and poly_sites:
            seq = "".join(seq[i] for i in poly_sites)
            text = render_sequence_text(seq, set(range(len(seq))), dim_non_poly=False)
        else:
            text = render_sequence_text(seq, highlight, dim_non_poly=not show_all_columns)
        table.add_row(rec.id, text)
        rows_shown += 1

    if len(alignment) > max_sequences:
        table.caption = f"Showing {max_sequences} / {len(alignment)} sequences"

    console.print(table)


def write_html(
    alignment: MultipleSeqAlignment,
    poly_sites: Sequence[int],
    output_html: str,
    show_all_columns: bool,
) -> None:
    """Write HTML visualization with CSS-based nucleotide coloring."""
    highlight = set(poly_sites)

    def color_span(base: str, is_poly: bool) -> str:
        b = base.upper()
        color = HTML_COLORS.get(b, "#212121")
        opacity = "1.0" if is_poly or show_all_columns else "0.35"
        return f'<span class="base" style="color:{color};opacity:{opacity}">{html.escape(base)}</span>'

    with open(output_html, "wt", encoding="utf-8") as out:
        out.write(
            """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>MSA Polymorphism Visualization</title>
<style>
body { font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, "Liberation Mono", monospace; margin: 1rem; }
.row { display: grid; grid-template-columns: minmax(180px, 280px) 1fr; gap: 0.75rem; margin: 0.2rem 0; }
.seqid { font-weight: 600; overflow-wrap: anywhere; }
.seq { white-space: pre; overflow-x: auto; }
.base { font-weight: 700; }
.small { color: #666; margin-bottom: 1rem; }
</style>
</head>
<body>
<h1>MSA Polymorphism Visualization</h1>
"""
        )
        out.write(
            f'<div class="small">Sequences: {len(alignment)} | Length: {alignment.get_alignment_length()} | '
            f'Polymorphic sites: {len(poly_sites)}</div>\n'
        )

        for rec in track(alignment, description="Writing HTML rows"):
            sequence = str(rec.seq)
            if not show_all_columns and poly_sites:
                rendered = "".join(color_span(sequence[i], True) for i in poly_sites)
            else:
                rendered = "".join(color_span(base, idx in highlight) for idx, base in enumerate(sequence))
            out.write(
                f'<div class="row"><div class="seqid">{html.escape(rec.id)}</div><div class="seq">{rendered}</div></div>\n'
            )

        out.write("</body>\n</html>\n")


def print_stats(stats: AlignmentStats, console: Console) -> None:
    """Render alignment statistics table in terminal."""
    t = Table(title="Polymorphism Statistics")
    t.add_column("Metric")
    t.add_column("Value", justify="right")
    t.add_row("Sequences", str(stats.sequence_count))
    t.add_row("Alignment length", str(stats.alignment_length))
    t.add_row("Polymorphic sites", str(stats.polymorphic_sites))
    t.add_row("Conserved sites", str(stats.conserved_sites))
    t.add_row("Polymorphic fraction", f"{stats.polymorphic_fraction:.4f}")
    t.add_row("Mean conservation", f"{stats.mean_conservation:.4f}")
    t.add_row("Mean entropy", f"{stats.mean_entropy:.4f}")
    t.add_row("Transitions", str(stats.transition_count))
    t.add_row("Transversions", str(stats.transversion_count))
    t.add_row("Ti/Tv ratio", "NA" if stats.ti_tv_ratio is None else f"{stats.ti_tv_ratio:.4f}")
    console.print(t)


def validate_input(path: str) -> None:
    """Validate that input file exists and is non-empty."""
    if not os.path.exists(path):
        raise FileNotFoundError(f"Input file not found: {path}")
    if os.path.getsize(path) == 0:
        raise ValueError(f"Input file is empty: {path}")


def parse_args(argv: Sequence[str]) -> argparse.Namespace:
    """Build CLI argument parser and parse arguments."""
    p = argparse.ArgumentParser(description="MSA polymorphism visualizer for nucleotide FASTA files")
    p.add_argument("input", help="Input FASTA or FASTA.GZ")
    p.add_argument("--aligned-input", action="store_true", help="Input is already aligned; skip MSA step")
    p.add_argument("--aligner", choices=["auto", "famsa", "mafft"], default="auto", help="Aligner to use")
    p.add_argument("--threads", type=int, default=1, help="Thread count for aligner")
    p.add_argument("--aligned-out", default="aligned.fasta", help="Output path for alignment")
    p.add_argument("--show-all-columns", action="store_true", help="Show all columns instead of only polymorphic loci")
    p.add_argument("--max-terminal-seqs", type=int, default=60, help="Max sequences printed in terminal")
    p.add_argument("--html-out", default=None, help="Write HTML visualization to this path")
    p.add_argument("--cluster-k", type=int, default=0, help="Optional KMeans cluster count for SNP patterns")
    p.add_argument("--check-tools", action="store_true", help="Only check aligner availability and exit")
    return p.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    """CLI entrypoint."""
    args = parse_args(argv or sys.argv[1:])
    console = Console()

    tools = check_alignment_tools()
    if args.check_tools:
        console.print("Alignment tool availability:")
        for name, value in tools.items():
            console.print(f"- {name}: {'FOUND at ' + value if value else 'NOT FOUND'}")
        return 0

    try:
        validate_input(args.input)

        seq_count = count_fasta_sequences(args.input)
        console.print(f"Input sequences detected: {seq_count}")
        if seq_count < 2:
            raise ValueError("Need at least 2 sequences for alignment/statistics.")

        aligned_path = args.input if args.aligned_input else args.aligned_out

        if not args.aligned_input:
            aligner = args.aligner
            if aligner == "auto":
                aligner = choose_aligner("auto")
            console.print(f"Running alignment with {aligner}...")
            run_msa(args.input, aligned_path, aligner=aligner, threads=max(1, args.threads))
            console.print(f"Aligned FASTA written to {aligned_path}")

        alignment = read_alignment(aligned_path)
        poly_sites = polymorphic_positions(alignment)
        stats = calculate_stats(alignment, poly_sites)

        render_terminal(
            alignment,
            poly_sites,
            show_all_columns=args.show_all_columns,
            max_sequences=max(1, args.max_terminal_seqs),
            console=console,
        )
        print_stats(stats, console)

        if args.cluster_k and args.cluster_k > 1:
            clusters = cluster_snps(alignment, poly_sites, args.cluster_k)
            ctable = Table(title=f"SNP Clusters (k={args.cluster_k})")
            ctable.add_column("Sequence")
            ctable.add_column("Cluster", justify="right")
            for seq_id, label in clusters:
                ctable.add_row(seq_id, str(label))
            console.print(ctable)

        if args.html_out:
            write_html(alignment, poly_sites, args.html_out, show_all_columns=args.show_all_columns)
            console.print(f"HTML visualization written to {args.html_out}")

    except Exception as exc:
        console.print(f"[bold red]Error:[/bold red] {exc}")
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
