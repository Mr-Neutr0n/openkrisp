#!/usr/bin/env python3
"""Plot an explicitly supplied measurement JSON. Never opens an audio/model file."""
import argparse
import json
import math
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("metrics", type=Path, help="Explicit local metrics JSON")
    parser.add_argument("output", type=Path, help="New .png or .svg destination")
    args = parser.parse_args()
    if args.output.suffix.lower() not in {".png", ".svg"}:
        parser.error("output must be .png or .svg")
    if args.output.exists():
        parser.error("output already exists")
    data = json.loads(args.metrics.read_text())
    names = ["RNNoise", "installed outbound NC"]
    scores, attenuation = [], []
    for name in names:
        engine = data["engines"][name]
        scores.append([engine["cleanControl"]["rawReferenceErrorScoreDb"],
                       *[engine["conditions"][c]["outputVsCleanInput"]["rawReferenceErrorScoreDb"]
                         for c in ["stationary", "bursty"]]])
        attenuation.append([engine["conditions"][c]["noiseOnlyAttenuationDb"]
                            for c in ["stationary", "bursty"]])
    if not all(math.isfinite(x) for series in [*scores, *attenuation] for x in series):
        parser.error("all plotted measurements must be finite")
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    plt.rcParams.update({"font.family": "DejaVu Sans", "font.size": 10,
                         "axes.spines.top": False, "axes.spines.right": False,
                         "axes.titleweight": "bold"})
    fig, axes = plt.subplots(1, 2, figsize=(11.5, 5.7))
    fig.subplots_adjust(left=.075, right=.98, bottom=.29, top=.70, wspace=.25)
    colors = ["#286487", "#bd653e"]
    for ax, values, labels, title, ylabel in [
        (axes[0], scores, ["Clean speech", "Stationary\nmixture", "Bursty\nmixture"],
         "Sample difference from clean reference", "Reference-error score (dB)"),
        (axes[1], attenuation, ["Stationary\nnoise", "Bursty\nnoise"],
         "Separate noise-only controls", "Noise-only attenuation (dB)")]:
        for index, (name, series, color) in enumerate(zip(names, values, colors)):
            bars = ax.bar([x + (index - .5) * .34 for x in range(len(labels))], series,
                          width=.32, color=color, label=name)
            ax.bar_label(bars, fmt="%.2f", padding=4, fontsize=9)
        ax.set_xticks(range(len(labels)), labels)
        ax.set_title(title, fontsize=11, pad=15)
        ax.set_ylabel(ylabel)
        ax.grid(axis="y", color="#e0e4e7", linewidth=.7)
        ax.set_axisbelow(True)
        ax.set_ylim(0, max(max(x) for x in values) * 1.2)
    fig.suptitle("Noise-processing comparison", x=.075, y=.96, ha="left", fontsize=18, fontweight="bold")
    fig.text(.075, .885, "Same 10-second generated-speech fixture, mono 48 kHz. Mixtures have about 10 dB input SNR.", fontsize=10)
    handles, labels = axes[0].get_legend_handles_labels()
    fig.legend(handles, labels, loc="upper left", bbox_to_anchor=(.068, .835), ncol=2, frameon=False)
    fig.text(.075, .16, "Higher reference-error scores mean less aligned sample error here. Filtering, gain changes and deleted speech affect this score.", fontsize=9)
    fig.text(.075, .12, "Noise-only attenuation does not measure suppression during speech. These measurements do not establish human speech quality.", fontsize=9)
    fig.text(.075, .08, "Delay is measured separately in COMPARISON.md. Installed NC is a native-worker experiment, not the full original desktop pipeline.", fontsize=9)
    fig.text(.075, .035, "2026-11-05  |  Local synthesized English speech and synthetic noises only  |  No raw audio or original models included", color="#59636b", fontsize=8)
    fig.savefig(args.output, dpi=180, facecolor="white", metadata={"Title": "Controlled noise-processing comparison"})
    plt.close(fig)


if __name__ == "__main__":
    main()
