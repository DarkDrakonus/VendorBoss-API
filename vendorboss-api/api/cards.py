"""
Cards endpoints
Search and retrieve card catalog data
Covers both TCG cards and sports cards
"""
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import or_, func
from typing import Optional, List
from datetime import datetime
from decimal import Decimal
from pydantic import BaseModel

import models
from database import get_db
from auth import get_current_user

router = APIRouter(prefix="/cards", tags=["Cards"])

# ── Schemas ───────────────────────────────────────────────────────────────────

class TCGCardResponse(BaseModel):
    tcg_id: str
    product_id: str
    card_name: str
    card_number: Optional[str]
    rarity: Optional[str]
    card_type: Optional[str]
    set_id: Optional[str]
    is_foil: Optional[bool]
    variant_type: Optional[str]
    image_url: Optional[str]
    # Game-specific
    element: Optional[str]       # FFTCG
    cost: Optional[int]          # FFTCG
    power: Optional[int]         # FFTCG
    pokemon_type: Optional[str]  # Pokemon
    hp: Optional[int]            # Pokemon
    mana_cost: Optional[str]     # Magic
    color: Optional[str]         # Magic

    class Config:
        from_attributes = True

class SportsCardResponse(BaseModel):
    card_id: str
    product_id: str
    player: str
    team: Optional[str]
    year: Optional[int]
    set_id: Optional[str]
    card_number: Optional[str]
    variant_name: Optional[str]
    rookie_card: Optional[bool]
    autograph: Optional[bool]
    graded: Optional[bool]
    grading_company: Optional[str]
    grade: Optional[str]

    class Config:
        from_attributes = True

class CardSearchResponse(BaseModel):
    tcg_cards: List[TCGCardResponse]
    sports_cards: List[SportsCardResponse]
    total_tcg: int
    total_sports: int

class PriceHistoryItem(BaseModel):
    source: str
    price: Decimal
    condition: Optional[str]
    price_date: datetime

    class Config:
        from_attributes = True

class CardDetailResponse(BaseModel):
    product_id: str
    tcg_detail: Optional[TCGCardResponse]
    sports_detail: Optional[SportsCardResponse]
    price_history: List[PriceHistoryItem]
    latest_price: Optional[Decimal]

# ── Endpoints ─────────────────────────────────────────────────────────────────

@router.get("/search", response_model=CardSearchResponse)
def search_cards(
    q: str = Query(..., min_length=2, description="Search by card name, player, set, or card number"),
    category: Optional[str] = Query(None, description="'tcg' or 'sports' to narrow results"),
    sport_id: Optional[str] = None,
    set_id: Optional[str] = None,
    year: Optional[int] = None,
    limit: int = Query(20, ge=1, le=100),
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """
    Search the card catalog.
    Returns matching TCG cards and/or sports cards.
    Used by the scan confirmation screen and manual add card screen.
    """
    tcg_cards = []
    sports_cards = []
    total_tcg = 0
    total_sports = 0

    if category != "sports":
        tcg_query = db.query(models.TcgDetail).filter(
            or_(
                func.lower(models.TcgDetail.card_name).contains(q.lower()),
                func.lower(models.TcgDetail.card_number).contains(q.lower()),
            )
        )
        if set_id:
            tcg_query = tcg_query.filter(models.TcgDetail.set_id == set_id)

        total_tcg = tcg_query.count()
        tcg_cards = tcg_query.limit(limit).all()

    if category != "tcg":
        sports_query = db.query(models.CardDetail).filter(
            or_(
                func.lower(models.CardDetail.player).contains(q.lower()),
                func.lower(models.CardDetail.team).contains(q.lower()),
                func.lower(models.CardDetail.card_number).contains(q.lower()),
            )
        )
        if sport_id:
            sports_query = sports_query.filter(models.CardDetail.sport_id == sport_id)
        if set_id:
            sports_query = sports_query.filter(models.CardDetail.set_id == set_id)
        if year:
            sports_query = sports_query.filter(models.CardDetail.year == year)

        total_sports = sports_query.count()
        sports_cards = sports_query.limit(limit).all()

    return CardSearchResponse(
        tcg_cards=tcg_cards,
        sports_cards=sports_cards,
        total_tcg=total_tcg,
        total_sports=total_sports
    )


@router.get("/{product_id}", response_model=CardDetailResponse)
def get_card(
    product_id: str,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """Get full card detail including price history."""
    # Check product exists
    product = db.query(models.Product).filter(
        models.Product.product_id == product_id
    ).first()
    if not product:
        raise HTTPException(status_code=404, detail="Card not found")

    tcg_detail = db.query(models.TcgDetail).filter(
        models.TcgDetail.product_id == product_id
    ).first()

    sports_detail = db.query(models.CardDetail).filter(
        models.CardDetail.product_id == product_id
    ).first()

    price_history = db.query(models.PriceHistory).filter(
        models.PriceHistory.product_id == product_id
    ).order_by(models.PriceHistory.price_date.desc()).limit(50).all()

    latest_price = price_history[0].price if price_history else None

    return CardDetailResponse(
        product_id=product_id,
        tcg_detail=tcg_detail,
        sports_detail=sports_detail,
        price_history=price_history,
        latest_price=latest_price
    )


@router.get("/{product_id}/price-history", response_model=List[PriceHistoryItem])
def get_price_history(
    product_id: str,
    source: Optional[str] = None,
    limit: int = Query(30, ge=1, le=200),
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """Get price history for a card."""
    query = db.query(models.PriceHistory).filter(
        models.PriceHistory.product_id == product_id
    )
    if source:
        query = query.filter(models.PriceHistory.source == source)

    return query.order_by(
        models.PriceHistory.price_date.desc()
    ).limit(limit).all()
