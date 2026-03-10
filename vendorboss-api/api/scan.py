"""
Scan endpoints
AI-powered card identification from images
Uses Google Gemini vision to extract card details,
then searches the catalog for matches with confidence scoring.
"""
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from sqlalchemy.orm import Session
from sqlalchemy import or_, func
from typing import Optional, List
from decimal import Decimal
from pydantic import BaseModel
import google.genai as genai
import json
import uuid
import os
import logging
import traceback

import models
from database import get_db
from auth import get_current_user

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/scan", tags=["Scan"])

# ── Gemini client ─────────────────────────────────────────────────────────────
_gemini_client = genai.Client(api_key=os.getenv("GEMINI_API_KEY"))

# ── Schemas ───────────────────────────────────────────────────────────────────

class ExtractedCardData(BaseModel):
    """Raw data extracted from the image by AI"""
    card_name: Optional[str] = None
    player_name: Optional[str] = None
    card_number: Optional[str] = None
    set_name: Optional[str] = None
    year: Optional[str] = None
    sport: Optional[str] = None
    team: Optional[str] = None
    rarity: Optional[str] = None
    card_type: Optional[str] = None    # "tcg" or "sports"
    condition_estimate: Optional[str] = None
    is_graded: bool = False
    grading_company: Optional[str] = None
    grade: Optional[str] = None
    is_foil: bool = False
    notes: Optional[str] = None       # anything else AI noticed

class ScanMatch(BaseModel):
    """A candidate card match with confidence score"""
    product_id: str
    confidence: float              # 0.0 - 1.0
    match_reasons: List[str]       # why this matched
    card_name: Optional[str] = None
    player_name: Optional[str] = None
    card_number: Optional[str] = None
    set_name: Optional[str] = None
    year: Optional[int] = None
    sport: Optional[str] = None
    image_url: Optional[str] = None
    latest_price: Optional[Decimal] = None

class ScanResponse(BaseModel):
    scan_id: str
    extracted: ExtractedCardData
    matches: List[ScanMatch]
    top_match: Optional[ScanMatch] = None
    catalog_searched: bool

class ScanConfirmRequest(BaseModel):
    scan_id: str
    product_id: str                # confirmed product
    # Inventory fields to create the item
    purchase_price: Optional[Decimal] = None
    asking_price: Optional[Decimal] = None
    condition: Optional[str] = None
    quantity: int = 1
    show_id: Optional[str] = None
    notes: Optional[str] = None

class ScanConfirmResponse(BaseModel):
    inventory_id: str
    product_id: str
    message: str

# ── AI extraction ─────────────────────────────────────────────────────────────

EXTRACTION_PROMPT = """You are a trading card expert. Analyze this image of a trading card and extract all visible information.

Return ONLY a JSON object with these fields (use null for anything not visible):
{
  "card_name": "name of the card or character",
  "player_name": "athlete name if sports card",
  "card_number": "card number e.g. 123/456 or 8-132L",
  "set_name": "set or series name",
  "year": "year as string",
  "sport": "sport name if sports card",
  "team": "team name if sports card",
  "rarity": "rarity if visible e.g. Rare, Legend, Common",
  "card_type": "tcg or sports",
  "condition_estimate": "NM, LP, MP, HP, or Poor based on visible wear",
  "is_graded": false,
  "grading_company": "PSA, BGS, CGC etc if graded",
  "grade": "grade number if graded",
  "is_foil": false,
  "notes": "anything else notable about this card"
}

Be precise with card numbers and names. If you cannot determine card_type, use null."""


def extract_card_data(image_bytes: bytes, media_type: str) -> ExtractedCardData:
    """Send image to Gemini and extract card details."""
    from google.genai import types as genai_types
    import base64

    image_part = genai_types.Part.from_bytes(
        data=image_bytes,
        mime_type=media_type,
    )

    response = _gemini_client.models.generate_content(
        model="gemini-2.0-flash",
        contents=[image_part, EXTRACTION_PROMPT],
    )

    raw = response.text.strip()

    # Strip markdown code fences if present
    if raw.startswith("```"):
        raw = raw.split("```")[1]
        if raw.startswith("json"):
            raw = raw[4:]
    raw = raw.strip()

    data = json.loads(raw)
    return ExtractedCardData(**data)


def find_catalog_matches(extracted: ExtractedCardData, db: Session) -> List[ScanMatch]:
    """Search catalog for cards matching the extracted data."""
    matches = []

    # ── TCG search ────────────────────────────────────────────────────────────
    if extracted.card_type in (None, "tcg") and (extracted.card_name or extracted.card_number):
        tcg_query = db.query(models.TcgDetail)
        filters = []

        if extracted.card_name:
            filters.append(
                func.lower(models.TcgDetail.card_name).contains(extracted.card_name.lower())
            )
        if extracted.card_number:
            filters.append(
                func.lower(models.TcgDetail.card_number).contains(extracted.card_number.lower())
            )

        if filters:
            tcg_results = tcg_query.filter(or_(*filters)).limit(5).all()
            for card in tcg_results:
                reasons = []
                confidence = 0.0

                if extracted.card_name and extracted.card_name.lower() in (card.card_name or "").lower():
                    reasons.append(f"Card name matches: {card.card_name}")
                    confidence += 0.5
                if extracted.card_number and extracted.card_number.lower() in (card.card_number or "").lower():
                    reasons.append(f"Card number matches: {card.card_number}")
                    confidence += 0.4
                if extracted.rarity and extracted.rarity.lower() == (card.rarity or "").lower():
                    reasons.append(f"Rarity matches: {card.rarity}")
                    confidence += 0.1

                if confidence > 0:
                    # Get latest price
                    price_record = db.query(models.PriceHistory).filter(
                        models.PriceHistory.product_id == card.product_id
                    ).order_by(models.PriceHistory.price_date.desc()).first()

                    matches.append(ScanMatch(
                        product_id=card.product_id,
                        confidence=min(confidence, 1.0),
                        match_reasons=reasons,
                        card_name=card.card_name,
                        card_number=card.card_number,
                        image_url=card.image_url,
                        latest_price=price_record.price if price_record else None
                    ))

    # ── Sports card search ────────────────────────────────────────────────────
    if extracted.card_type in (None, "sports") and (extracted.player_name or extracted.card_number):
        sports_query = db.query(models.CardDetail)
        filters = []

        if extracted.player_name:
            filters.append(
                func.lower(models.CardDetail.player).contains(extracted.player_name.lower())
            )
        if extracted.card_number:
            filters.append(
                func.lower(models.CardDetail.card_number).contains(extracted.card_number.lower())
            )

        if filters:
            sports_results = sports_query.filter(or_(*filters)).limit(5).all()
            for card in sports_results:
                reasons = []
                confidence = 0.0

                if extracted.player_name and extracted.player_name.lower() in (card.player or "").lower():
                    reasons.append(f"Player matches: {card.player}")
                    confidence += 0.45
                if extracted.card_number and extracted.card_number.lower() in (card.card_number or "").lower():
                    reasons.append(f"Card number matches: {card.card_number}")
                    confidence += 0.35
                if extracted.year and str(extracted.year) == str(card.year):
                    reasons.append(f"Year matches: {card.year}")
                    confidence += 0.1
                if extracted.team and extracted.team.lower() in (card.team or "").lower():
                    reasons.append(f"Team matches: {card.team}")
                    confidence += 0.1

                if confidence > 0:
                    price_record = db.query(models.PriceHistory).filter(
                        models.PriceHistory.product_id == card.product_id
                    ).order_by(models.PriceHistory.price_date.desc()).first()

                    matches.append(ScanMatch(
                        product_id=card.product_id,
                        confidence=min(confidence, 1.0),
                        match_reasons=reasons,
                        player_name=card.player,
                        card_number=card.card_number,
                        year=card.year,
                        latest_price=price_record.price if price_record else None
                    ))

    # Sort by confidence descending
    matches.sort(key=lambda m: m.confidence, reverse=True)
    return matches[:5]  # Return top 5


# ── Endpoints ─────────────────────────────────────────────────────────────────

@router.post("/", response_model=ScanResponse)
async def scan_card(
    image: UploadFile = File(..., description="Card image — JPEG or PNG"),
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """
    Submit a card image for AI identification.
    Returns extracted card data and catalog matches with confidence scores.
    The client presents the top matches to the user for confirmation.
    """
    # Validate file type
    if image.content_type not in ("image/jpeg", "image/png", "image/webp"):
        raise HTTPException(
            status_code=400,
            detail="Image must be JPEG, PNG, or WebP"
        )

    image_bytes = await image.read()
    if len(image_bytes) > 10 * 1024 * 1024:  # 10MB limit
        raise HTTPException(status_code=400, detail="Image too large — max 10MB")

    # Extract card data via Claude vision
    try:
        extracted = extract_card_data(image_bytes, image.content_type)
    except json.JSONDecodeError:
        raise HTTPException(
            status_code=422,
            detail="Could not parse card data from image — try a clearer photo"
        )
    except Exception as e:
        logger.error("AI extraction failed: %s\n%s", str(e), traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"AI extraction failed: {str(e)}")

    # Search catalog for matches
    matches = find_catalog_matches(extracted, db)
    catalog_searched = bool(extracted.card_name or extracted.player_name or extracted.card_number)

    # Log the scan
    scan_id = str(uuid.uuid4())
    scan_record = models.Scan(
        scan_id=scan_id,
        user_id=current_user.user_id,
        scan_type="ai_vision",
        detected_player=extracted.player_name,
        detected_sport=extracted.sport,
        detected_team=extracted.team,
        detected_year=int(extracted.year) if extracted.year and extracted.year.isdigit() else None,
        detected_set=extracted.set_name,
        detected_card_number=extracted.card_number,
        product_id=matches[0].product_id if matches else None,
        verified=False,
    )
    db.add(scan_record)
    db.commit()

    return ScanResponse(
        scan_id=scan_id,
        extracted=extracted,
        matches=matches,
        top_match=matches[0] if matches else None,
        catalog_searched=catalog_searched
    )


@router.post("/confirm", response_model=ScanConfirmResponse)
def confirm_scan(
    confirm: ScanConfirmRequest,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """
    Confirm a scan match and add the card to inventory.
    Called after the user selects the correct card from the scan results.
    """
    # Verify product exists
    product = db.query(models.Product).filter(
        models.Product.product_id == confirm.product_id
    ).first()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")

    # Mark scan as verified
    scan = db.query(models.Scan).filter(
        models.Scan.scan_id == confirm.scan_id,
        models.Scan.user_id == current_user.user_id
    ).first()
    if scan:
        scan.product_id = confirm.product_id
        scan.verified = True

    # Look up show if provided
    show_name = None
    if confirm.show_id:
        show = db.query(models.Show).filter(
            models.Show.show_id == confirm.show_id,
            models.Show.user_id == current_user.user_id
        ).first()
        if show:
            show_name = show.show_name

    # Add to inventory
    from datetime import date
    inventory_item = models.Inventory(
        inventory_id=str(uuid.uuid4()),
        user_id=current_user.user_id,
        product_id=confirm.product_id,
        quantity=confirm.quantity,
        available_quantity=confirm.quantity,
        purchase_price=confirm.purchase_price,
        asking_price=confirm.asking_price,
        condition=confirm.condition or "NM",
        notes=confirm.notes,
        for_sale=True,
        acquired_date=date.today(),
    )

    db.add(inventory_item)
    db.commit()
    db.refresh(inventory_item)

    return ScanConfirmResponse(
        inventory_id=inventory_item.inventory_id,
        product_id=confirm.product_id,
        message="Card added to inventory successfully"
    )
