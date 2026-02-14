"""
Local RAG service for MSME credit/scheme handbook data.
"""

from __future__ import annotations

import json
import logging
import re
from pathlib import Path
from typing import Any, Dict, List, Optional, Set

logger = logging.getLogger(__name__)


class MSMECreditRAGService:
    STOPWORDS: Set[str] = {
        "a", "an", "and", "are", "as", "at", "be", "by", "for", "from", "if",
        "in", "into", "is", "it", "of", "on", "or", "that", "the", "to", "up",
        "with", "your", "you", "this", "under", "through", "all", "can", "loan",
    }

    def __init__(self) -> None:
        self._loaded = False
        self._source: Dict[str, Any] = {}
        self._chunks: List[Dict[str, Any]] = []
        self._kb_path = (
            Path(__file__).resolve().parent.parent
            / "data"
            / "knowledge_base"
            / "msme_credit_handbook_rag.json"
        )

    def _ensure_loaded(self) -> None:
        if self._loaded:
            return
        if not self._kb_path.exists():
            logger.warning("MSME credit RAG KB missing at %s", self._kb_path)
            self._loaded = True
            return

        with self._kb_path.open("r", encoding="utf-8") as handle:
            data = json.load(handle)

        self._source = data.get("source", {})
        chunks = data.get("chunks", [])
        if not isinstance(chunks, list):
            chunks = []
        self._chunks = [chunk for chunk in chunks if isinstance(chunk, dict)]
        self._loaded = True

    @property
    def is_available(self) -> bool:
        self._ensure_loaded()
        return bool(self._chunks)

    def retrieve(
        self,
        query: str,
        *,
        top_k: int = 4,
        extra_terms: Optional[List[str]] = None,
    ) -> Dict[str, Any]:
        self._ensure_loaded()
        if not self._chunks:
            return {"source": self._source, "matches": []}

        query_tokens = self._tokenize(query or "")
        for term in extra_terms or []:
            query_tokens.update(self._tokenize(term))

        scored: List[Dict[str, Any]] = []
        for chunk in self._chunks:
            score, matched_terms = self._score_chunk(chunk, query_tokens)
            if score <= 0:
                continue
            scored.append(
                {
                    "id": chunk.get("id"),
                    "title": chunk.get("title"),
                    "section": chunk.get("section"),
                    "content": chunk.get("content"),
                    "tags": chunk.get("tags", []),
                    "score": score,
                    "matched_terms": matched_terms,
                }
            )

        if not scored:
            defaults = self._chunks[: min(3, len(self._chunks))]
            return {
                "source": self._source,
                "matches": [
                    {
                        "id": chunk.get("id"),
                        "title": chunk.get("title"),
                        "section": chunk.get("section"),
                        "content": chunk.get("content"),
                        "tags": chunk.get("tags", []),
                        "score": 0,
                        "matched_terms": [],
                    }
                    for chunk in defaults
                ],
            }

        scored.sort(key=lambda item: item["score"], reverse=True)
        return {"source": self._source, "matches": scored[:top_k]}

    def format_for_prompt(self, rag_payload: Dict[str, Any]) -> str:
        source = rag_payload.get("source", {})
        matches = rag_payload.get("matches", []) or []

        lines = [
            "LOCAL MSME HANDBOOK RAG CONTEXT (policy-grounded):",
            f"Source: {source.get('title', 'MSME handbook')} | {source.get('publisher', 'Government source')}",
        ]
        if not matches:
            lines.append("No relevant handbook snippets found.")
            return "\n".join(lines)

        for idx, item in enumerate(matches, 1):
            lines.append(
                f"{idx}. [{item.get('section', 'Section')}] {item.get('title', 'Context')}: {item.get('content', '')}"
            )

        lines.append(
            "Use these snippets as factual grounding. If user data is missing, ask for it before confirming legal eligibility."
        )
        return "\n".join(lines)

    def _score_chunk(self, chunk: Dict[str, Any], query_tokens: Set[str]) -> tuple[int, List[str]]:
        if not query_tokens:
            return 0, []

        text_tokens = self._tokenize(
            f"{chunk.get('title', '')} {chunk.get('content', '')} {chunk.get('section', '')}"
        )
        tag_tokens = self._tokenize(" ".join(chunk.get("tags", [])))
        overlap = query_tokens.intersection(text_tokens)
        tag_overlap = query_tokens.intersection(tag_tokens)

        score = (2 * len(overlap)) + (3 * len(tag_overlap))
        matched = sorted(overlap.union(tag_overlap))
        return score, matched

    def _tokenize(self, text: str) -> Set[str]:
        tokens = set(re.findall(r"[a-zA-Z0-9]+", (text or "").lower()))
        return {tok for tok in tokens if tok and tok not in self.STOPWORDS}


msme_credit_rag_service = MSMECreditRAGService()

