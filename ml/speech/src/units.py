"""Unit-span references for the remediation loop: scoring a said unit / blend, and adult model audio.

A span (a, b) is an inclusive range of a word's units, e.g. (1, 1) = the 2nd akshara alone and
(1, 2) = the 2nd and 3rd blended. Span references are cut from every bank reference that has unit
boundaries (same trimmed audio the boundaries were aligned on), embedded, and given an acceptance
range learned exactly like whole words (src/threshold.py). Everything is computed on first use and
cached; invalidate(word_id) drops a word's cache when its bank changes.

Model audio for the LISTEN step comes from ADULT references only (owner decision 2026-10-16:
children's research recordings are never played to other children). The most typical adult
recording (lowest mean DTW cost to all references of that span) is used.
"""

from __future__ import annotations

import numpy as np

from src.audio import load_audio
from src.bank import ReferenceBank
from src.dtw_fast import dtw as fast_dtw
from src.dtw_fast import dtw_cost
from src.scoring import cosine_cost_matrix
from src.threshold import AcceptanceRange, acceptance_range

PAD_S = 0.0  # no padding: neighbour bleed makes a unit said ALONE look unlike its cut references
LISTEN_PAD_S = 0.15  # silence around model audio so playback does not clip


class SpanBank:
    def __init__(self, bank: ReferenceBank, embedder, settings: dict):
        self.bank, self.embedder, self.settings = bank, embedder, settings
        self._wav: dict[tuple[str, str], np.ndarray] = {}
        self._refs: dict[tuple[str, int, int], list[dict]] = {}
        self._ranges: dict[tuple[str, int, int], AcceptanceRange] = {}

    def units(self, word_id: str) -> list[str]:
        return self.bank.words[word_id]["units"].split("|")

    def invalidate(self, word_id: str) -> None:
        for cache in (self._wav, self._refs, self._ranges):
            for key in [k for k in cache if k[0] == word_id]:
                del cache[key]

    def _audio(self, word_id: str, ref_id: str) -> np.ndarray:
        key = (word_id, ref_id)
        if key not in self._wav:
            a = self.settings["audio"]
            self._wav[key] = load_audio(
                self.bank.reference_dir / word_id / f"{ref_id}.wav",
                target_sr=a["sample_rate"],
                max_duration_s=60,
                trim_top_db=a["trim_top_db"],
            )
        return self._wav[key]

    def _cut(self, word_id: str, ref: dict, a: int, b: int, pad: float = PAD_S) -> np.ndarray:
        wav = self._audio(word_id, ref["variant_id"])
        sr = self.settings["audio"]["sample_rate"]
        s = max(0, int((ref["units"][a]["start_s"] - pad) * sr))
        e = min(wav.size, int((ref["units"][b]["end_s"] + pad) * sr))
        return wav[s:e]

    def span_refs(self, word_id: str, a: int, b: int) -> list[dict]:
        key = (word_id, a, b)
        if key not in self._refs:
            n = len(self.units(word_id))
            out = []
            for ref in self.bank.reference_set(word_id):
                if len(ref["units"]) != n:
                    continue
                clip = self._cut(word_id, ref, a, b)
                if clip.size < 640:  # < 40 ms: too short to embed meaningfully
                    continue
                out.append({**ref, "emb": self.embedder.embed(clip)})
            self._refs[key] = out
        return self._refs[key]

    def span_range(self, word_id: str, a: int, b: int) -> AcceptanceRange:
        key = (word_id, a, b)
        if key not in self._ranges:
            sc = self.settings["scoring"]
            self._ranges[key] = acceptance_range(
                self.span_refs(word_id, a, b),
                k=sc["k_nearest"],
                n_std=sc["n_std"],
                min_refs=sc["min_refs_for_bank_threshold"],
                fallback=sc["fallback_threshold"],
                dtw_fn=fast_dtw,
                loo_unit=sc.get("loo_unit", "token"),
            )
        return self._ranges[key]

    def listen_units(self, word_id: str) -> list[int]:
        """Units that have adult model audio."""
        adults = [r for r in self.bank.reference_set(word_id) if r["age_group"] == "adult"]
        n = len(self.units(word_id))
        return list(range(n)) if any(len(r["units"]) == n for r in adults) else []

    def has_word_audio(self, word_id: str) -> bool:
        return any(r["age_group"] == "adult" for r in self.bank.reference_set(word_id))

    def listen_clip(
        self, word_id: str, a: int | None = None, b: int | None = None
    ) -> tuple[str, np.ndarray] | None:
        """(ref_id, padded audio) of the most typical ADULT rendition of the word or span."""
        if a is None:
            refs = self.bank.reference_set(word_id)
        else:
            refs = self.span_refs(word_id, a, b)
        adults = [r for r in refs if r["age_group"] == "adult"]
        if not adults:
            return None
        best = min(
            adults,
            key=lambda r: np.mean(
                [dtw_cost(cosine_cost_matrix(r["emb"], o["emb"])) for o in refs if o is not r]
                or [0.0]
            ),
        )
        if a is None:
            clip = self._audio(word_id, best["variant_id"])
        else:
            clip = self._cut(word_id, best, a, b)
        sr = self.settings["audio"]["sample_rate"]
        silence = np.zeros(int(LISTEN_PAD_S * sr), dtype=np.float32)
        return best["variant_id"], np.concatenate([silence, clip, silence])
