#!/usr/bin/env python3
"""Hermes command-type TTS provider: pick the Edge voice matching the text's language.

Usage (as a Hermes command provider):
    python3 ~/.hermes/tts/langvoice.py {input_path} {output_path}

Detects the language of the text, maps it to a native Edge neural voice, and renders
the audio with edge-tts. Per-language voices can be overridden in
~/.hermes/tts/voices.json ({"es": "es-ES-ElviraNeural", ...}).
Logs every call to ~/.hermes/tts/langvoice.log for verification.
"""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
import time

HOME = os.path.expanduser("~/.hermes")
VOICES_FILE = os.path.join(HOME, "tts", "voices.json")
STICKY_FILE = os.path.join(HOME, "tts", "last_lang")
LOG_FILE = os.path.join(HOME, "tts", "langvoice.log")

DEFAULT_VOICES = {
    "es": "es-ES-XimenaNeural",
    "en": "en-US-AriaNeural",
    "it": "it-IT-IsabellaNeural",
    "pt": "pt-PT-RaquelNeural",
    "fr": "fr-FR-DeniseNeural",
    "de": "de-DE-SeraphinaMultilingualNeural",
}
DEFAULT_LANG = "es"

_WORDS = {
    "es": (
        "el la los las un una unos unas de del al a y o e que qué en por para con sin "
        "es son está están estoy estaba ser este esta esto estos estas ese esa eso mi tu su sus "
        "mis tus me te se nos os le les lo no sí si cuando cómo como más pero porque ya "
        "muy también hay ha han he has fue era voy vas va van tienes tengo tiene puedo puede "
        "quieres quiero ahora hoy mañana bien mal todo todos toda todas nada algo donde dónde "
        "hasta desde entre sobre bajo durante contra según aunque mientras entonces pues aquí "
        "ahí allí así solo sólo cada otro otra mismo misma mucho mucha muchos muchas poco "
        "pronto luego después antes siempre nunca tampoco hacer hace hecho ver visto "
        "gracias vale bueno claro"
    ),
    "en": (
        "the a an of to and or in on for with without is are was were be been being "
        "this that these those my your his her its our their it i you he she we they me him "
        "them us not yes if when how what why but because more most very there here have has "
        "had do does did can could will would should want need now today tomorrow well also "
        "about from at by as so up out just get got like know think make take say said one "
        "two all some any than then which who whom whose into over under "
        "before after while during between through again still only own same such both few "
        "other another much many please thanks hello hi okay"
    ),
    "it": (
        "il lo la i gli le un uno una di del della dei degli delle che e ed o od in "
        "per con senza è sono essere questo questa questi queste quello quella mio mia tuo tua "
        "suo sua mi ti si ci vi li al alla ai alle non sì se quando come più ma perché già "
        "molto anche ho hai ha abbiamo hanno era stato stata posso puoi può voglio vuoi vuole "
        "ora oggi domani bene male tutto tutti tutta tutte niente qualcosa dove fino da tra "
        "sopra sotto durante contro secondo mentre allora quindi qui qua lì là così solo "
        "ogni altro altra stesso stessa poco presto poi dopo prima sempre mai nemmeno grazie "
        "certo ciao salve"
    ),
    "pt": (
        "o a os as um uma uns umas de do da dos das que e ou em no na por para com sem "
        "é são ser este esta estes estas esse essa meu minha teu tua seu sua me te se nos lhe "
        "lhes ao aos não sim quando como mais mas porque já muito também há tenho tem temos "
        "têm era foi posso pode quero quer agora hoje amanhã bem mal tudo todos toda todas "
        "nada algo onde até desde entre sobre sob durante contra segundo embora enquanto "
        "então aqui aí ali assim só cada outro outra mesmo mesma pouco logo depois antes "
        "sempre nunca obrigado obrigada bom claro"
    ),
    "fr": (
        "le la les un une des du de et ou en pour avec sans est sont être ce cette ces "
        "mon ton son mes tes ses je tu il elle on nous vous ils elles me te se ne pas si quand "
        "comment comme plus mais parce qui déjà très aussi ai as avons ont était peux "
        "peut veux veut maintenant demain bien mal tout tous toute toutes rien "
        "quelque chose où jusqu depuis entre sur sous pendant contre selon alors donc ici là "
        "ainsi seul chaque autre même peu bientôt puis après avant toujours jamais merci bon "
        "clair"
    ),
    "de": (
        "der die das den dem des ein eine einen einem einer eines und oder in im an "
        "auf für mit ohne ist sind sein war waren zu von bei aus nach über unter durch gegen "
        "ich du er sie es wir ihr mich dich sich uns euch mein dein nicht nein ja "
        "wenn wie was warum aber weil mehr sehr auch schon noch jetzt heute morgen gut "
        "schlecht alles alle nichts etwas wo bis seit zwischen dann also hier dort so nur "
        "jeder jede jedes andere gleiche wenig bald danach vorher immer nie danke bitte "
        "hallo klar"
    ),
}
STOPWORDS = {lang: set(words.split()) for lang, words in _WORDS.items()}

# strong character / morphology cues: language -> list of (regex, weight)
CUES = {
    "es": [(r"ñ", 8), (r"[¿¡]", 8), (r"ción", 4), (r"\b(?:usted|ustedes)\b", 4)],
    "pt": [(r"[ãõ]", 8), (r"ção", 6), (r"\b(?:você|vocês|não)\b", 5)],
    "it": [(r"\b(?:gli|dello|della|degli|nella|nello)\b", 4), (r"zione", 5), (r"è", 3)],
    "fr": [(r"[çœ]", 6), (r"\bqu'", 3), (r"\b(?:c'est|n'est|j'ai)\b", 6)],
    "de": [(r"[äöüß]", 6)],
    "en": [(r"\bthe\b", 4), (r"\b(?:it's|don't|can't|won't|I'm)\b", 5), (r"tion\b", 2)],
}


def detect(text: str) -> tuple[str, dict[str, int]]:
    """Return (language, per-language score) for *text*."""
    low = " " + re.sub(r"\s+", " ", text.lower()) + " "
    tokens = re.findall(r"[a-zà-ÿ]+(?:'[a-zà-ÿ]+)?", low)
    scores: dict[str, int] = {}
    for lang, bag in STOPWORDS.items():
        score = 0
        for tok in tokens:
            if tok in bag:
                score += 1
            elif "'" in tok:
                head, _, tail = tok.partition("'")
                if head in bag or tail in bag:
                    score += 1
        for pattern, weight in CUES.get(lang, []):
            score += weight * min(len(re.findall(pattern, low)), 3)
        scores[lang] = score

    best = max(scores, key=lambda k: scores[k])
    if scores[best] == 0:
        return _sticky(), scores
    # tiny inputs and near-ties are unreliable: prefer the previous language
    ordered = sorted(scores.values(), reverse=True)
    if len(tokens) < 12 and ordered[0] - ordered[1] <= 1:
        return _sticky(), scores
    return best, scores


def _sticky() -> str:
    try:
        with open(STICKY_FILE, encoding="utf-8") as fh:
            lang = fh.read().strip()
        if lang in DEFAULT_VOICES:
            return lang
    except OSError:
        pass
    return DEFAULT_LANG


def _remember(lang: str) -> None:
    try:
        os.makedirs(os.path.dirname(STICKY_FILE), exist_ok=True)
        with open(STICKY_FILE, "w", encoding="utf-8") as fh:
            fh.write(lang)
    except OSError:
        pass


def voices() -> dict[str, str]:
    merged = dict(DEFAULT_VOICES)
    try:
        with open(VOICES_FILE, encoding="utf-8") as fh:
            custom = json.load(fh)
        if isinstance(custom, dict):
            merged.update({str(k).lower(): str(v) for k, v in custom.items() if v})
    except (OSError, ValueError):
        pass
    return merged


def edge_tts_bin() -> str:
    found = shutil.which("edge-tts")
    if found:
        return found
    for base in (os.path.join(HOME, "installs"), os.path.join(HOME, "hermes-agent")):
        for root, _dirs, files in os.walk(base):
            if "edge-tts" in files and root.endswith(os.path.join("venv", "bin")):
                return os.path.join(root, "edge-tts")
    raise SystemExit("edge-tts not found on PATH")


def main() -> int:
    if len(sys.argv) < 3:
        print("usage: langvoice.py <input_path> <output_path>", file=sys.stderr)
        return 2
    input_path, output_path = sys.argv[1], sys.argv[2]
    with open(input_path, encoding="utf-8", errors="replace") as fh:
        text = fh.read().strip()
    if not text:
        print("empty input", file=sys.stderr)
        return 1

    lang, scores = detect(text)
    voice_map = voices()
    voice = os.environ.get("LANGVOICE_FORCE_VOICE") or voice_map.get(lang, voice_map[DEFAULT_LANG])
    _remember(lang)

    cmd = [edge_tts_bin(), "--file", input_path, "--voice", voice,
           "--write-media", output_path, "--no-progress"]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        sys.stderr.write(result.stderr[-2000:])
        return result.returncode or 1

    try:
        os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)
        with open(LOG_FILE, "a", encoding="utf-8") as fh:
            fh.write(json.dumps({
                "ts": time.strftime("%Y-%m-%dT%H:%M:%S"),
                "lang": lang, "voice": voice, "chars": len(text),
                "scores": scores, "out": output_path,
            }, ensure_ascii=False) + "\n")
    except OSError:
        pass

    if not os.path.exists(output_path) or os.path.getsize(output_path) == 0:
        print("edge-tts produced no audio", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
