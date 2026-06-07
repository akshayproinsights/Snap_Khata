"""
Voice input parsing routes.

POST /api/voice/parse-items
  Accepts a raw speech-to-text transcript and an optional list of known
  catalogue items. Uses Gemini flash-lite to extract a structured list of
  {name, quantity, unit} objects.  Returns an empty list on any failure so
  the Flutter app can fall back to its built-in regex parser.
"""

import json
import logging
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

import auth
from config import get_google_api_key, get_free_google_api_key

logger = logging.getLogger(__name__)
router = APIRouter()


# ── Request / Response models ─────────────────────────────────────────────────

class ParseItemsRequest(BaseModel):
    transcript: str
    catalogue_names: Optional[List[str]] = None   # known item names for context


class ParsedItem(BaseModel):
    name: str
    quantity: float = 1.0
    unit: str = ""


class ParseItemsResponse(BaseModel):
    status: str
    items: List[ParsedItem]
    raw_transcript: str


# ── Gemini helpers ────────────────────────────────────────────────────────────

_SYSTEM_PROMPT = """\
You are a smart billing assistant for Indian kirana / grocery shops.
The shop owner speaks item names in a mix of English, Hindi, and Marathi.

Your job: extract a structured list of items from the spoken text.

Rules:
- Return ONLY valid JSON – no prose, no markdown.
- Format: {"items": [{"name": "...", "quantity": ..., "unit": "..."}]}
- name: clean English / common item name (Title Case). Use the closest
  match from the catalogue if provided, else normalise the spoken word.
- quantity: a number (float). Default 1.0 if not mentioned.
- unit: one of KG, GM, LTR, ML, PKT, BOX, DOZ. Default empty string ("") if not mentioned or if no specific unit applies (do NOT default to NOS).
- Ignore filler words (bhai, sahib, ek number, please, aaj, etc.).
- Handle number words: ek=1, do=2, teen=3, char=4, paanch=5, chhe=6,
  saat=7, aath=8, nau=9, das=10, barah=12, aadha=0.5, pav=0.25,
  savaa=1.25, dedh=1.5.
- Handle unit words: kilo/kg, litre/ltr/tel, gram/gm, packet/pkt,
  dozen/doz, box, piece/pcs, ml.
- If quantity appears AFTER the name ("atta 2 kilo"), parse correctly.
- If items are separated by comma, "and", "aur", "ani", treat as separate.
- Never return an empty items array unless the transcript has no items at all.
"""


def _call_gemini(transcript: str, catalogue_names: List[str]) -> List[Dict]:
    """
    Call Gemini flash-lite and return parsed items.
    Raises on any error – caller catches and returns empty list.
    """
    try:
        from google import genai
        from google.genai import types
    except ImportError:
        raise RuntimeError("google-genai SDK not installed")

    try:
        from google.genai import types
    except ImportError:
        raise RuntimeError("google-genai SDK not installed")

    from utils.gemini_client import generate_content_robust

    if not get_google_api_key() and not get_free_google_api_key():
        raise RuntimeError("Google API key not configured")

    # Build user message
    user_msg = f'Transcript: "{transcript}"'
    if catalogue_names:
        # Send top 50 catalogue names so Gemini can match spellings
        top = catalogue_names[:50]
        user_msg += f"\n\nKnown catalogue items (use these names when matching): {json.dumps(top)}"

    config = types.GenerateContentConfig(
        system_instruction=_SYSTEM_PROMPT,
        response_mime_type="application/json",
        temperature=0.0,
        max_output_tokens=1024,
    )

    # generate_content_robust tries Vertex AI first, then paid key, then free key
    logger.info("Calling Gemini (voice parsing) with model gemini-3.1-flash-lite via robust client...")
    response = generate_content_robust(
        model="gemini-3.1-flash-lite",
        contents=[user_msg],
        config=config,
        use_free_key=True,
    )

    text = (response.text or "").strip()
    # Strip markdown fences if model adds them despite mime type
    if text.startswith("```"):
        text = text.split("```", 2)[-1] if text.count("```") >= 2 else text
        text = text.lstrip("json").strip()
    if text.endswith("```"):
        text = text[:-3].strip()

    data = json.loads(text)
    raw_items = data.get("items", [])

    # Normalise each item
    parsed = []
    for it in raw_items:
        name = str(it.get("name") or "").strip()
        if not name:
            continue
        try:
            qty = float(it.get("quantity") or 1.0)
        except (TypeError, ValueError):
            qty = 1.0
        unit = str(it.get("unit") or "").strip().upper()
        if unit == "NOS":
            unit = ""
        if unit not in {"KG", "GM", "LTR", "ML", "PKT", "BOX", "DOZ", ""}:
            unit = ""
        parsed.append({"name": name, "quantity": qty, "unit": unit})

    return parsed


# ── Endpoint ──────────────────────────────────────────────────────────────────

@router.post("/parse-items", response_model=ParseItemsResponse)
async def parse_voice_items(
    request: ParseItemsRequest,
    current_user: Dict[str, Any] = Depends(auth.get_current_user),
):
    """
    Parse a voice transcript into a structured list of billing items.

    - Uses Gemini flash-lite for NLP extraction.
    - Returns status='success' with items on success.
    - Returns status='fallback' with an empty items list on any error,
      so the Flutter app can silently fall back to its regex parser.
    """
    transcript = (request.transcript or "").strip()
    if not transcript:
        return ParseItemsResponse(
            status="fallback",
            items=[],
            raw_transcript=transcript,
        )

    catalogue_names = request.catalogue_names or []

    try:
        raw = _call_gemini(transcript, catalogue_names)
        items = [
            ParsedItem(name=it["name"], quantity=it["quantity"], unit=it["unit"])
            for it in raw
        ]
        logger.info(
            f"[voice/parse-items] user={current_user.get('username')} "
            f"transcript='{transcript[:60]}' → {len(items)} items"
        )
        return ParseItemsResponse(
            status="success",
            items=items,
            raw_transcript=transcript,
        )
    except Exception as e:
        logger.warning(
            f"[voice/parse-items] Gemini parse failed for "
            f"user={current_user.get('username')}: {e}"
        )
        return ParseItemsResponse(
            status="fallback",
            items=[],
            raw_transcript=transcript,
        )
