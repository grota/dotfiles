#!/usr/bin/env python3
"""Build one audio comparison clip from several edge-tts voices.

Usage:
    python edge_voice_compare.py                      # default Spanish set
    python edge_voice_compare.py it-IT-ElsaNeural:Elsa,it-IT-DiegoNeural:Diego
    python edge_voice_compare.py --text "Ciao, prova." --out /tmp/cmp.mp3 v1:Label1 v2:Label2

Each voice announces itself ("Soy <Label>.") before --text, so the listener can map
what they hear to a voice id. Voices are concatenated with 0.35 s of silence.
Prints the final path and its duration. Requires `edge-tts` and `ffmpeg` on PATH.
"""
import argparse
import pathlib
import subprocess
import sys
import tempfile

DEFAULT = [
    "es-ES-XimenaNeural:Ximena, España, femenina",
    "es-ES-ElviraNeural:Elvira, España, femenina",
    "es-ES-AlvaroNeural:Álvaro, España, masculina",
    "es-MX-DaliaNeural:Dalia, México, femenina",
    "es-US-PalomaNeural:Paloma, español de EE.UU., femenina",
    "es-AR-TomasNeural:Tomás, Argentina, masculina",
    "es-CO-GonzaloNeural:Gonzalo, Colombia, masculina",
]
DEFAULT_TEXT = (
    "Mañana por la mañana voy a comprar el pan, y luego paso por el taller "
    "a recoger el coche."
)


def run(cmd):
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        sys.exit(f"FAILED: {' '.join(cmd)}\n{r.stderr[-800:]}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("voices", nargs="*", help="voiceId:Label pairs")
    ap.add_argument("--text", default=DEFAULT_TEXT)
    ap.add_argument("--intro", default="Soy {label}.")
    ap.add_argument("--out", default=None)
    ap.add_argument("--silence", default="0.35")
    a = ap.parse_args()

    pairs = []
    for item in a.voices or DEFAULT:
        vid, _, label = item.partition(":")
        pairs.append((vid.strip(), (label or vid).strip()))

    out = pathlib.Path(a.out or tempfile.mkdtemp(prefix="voicecmp_") + "/voice_compare.mp3")
    work = out.parent
    parts = []
    for i, (vid, label) in enumerate(pairs):
        f = work / f"{i:02d}_{vid}.mp3"
        run(["edge-tts", "--voice", vid, "--text",
             f"{a.intro.format(label=label)} {a.text}", "--write-media", str(f)])
        parts.append(f)
        print(f"ok  {vid:26s} {f.stat().st_size:7d} B  ({label})")

    sil = work / "sil.mp3"
    run(["ffmpeg", "-y", "-f", "lavfi", "-i", "anullsrc=r=24000:cl=mono",
         "-t", a.silence, "-acodec", "libmp3lame", str(sil)])
    lst = work / "list.txt"
    lst.write_text("".join(f"file '{p}'\nfile '{sil}'\n" for p in parts))
    run(["ffmpeg", "-y", "-f", "concat", "-safe", "0", "-i", str(lst),
         "-c:a", "libmp3lame", "-b:a", "96k", str(out)])

    dur = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration",
         "-of", "csv=p=0", str(out)], capture_output=True, text=True).stdout.strip()
    print(f"FINAL {out}  {out.stat().st_size} B  {dur}s   ({len(pairs)} voices)")


if __name__ == "__main__":
    main()
