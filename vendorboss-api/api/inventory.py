"""
Inventory endpoints
CRUD for a vendor's card inventory — returns enriched card details
"""
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from typing import Optional, List
from datetime import date, datetime
from decimal import Decimal
from pydantic import BaseModel

import models
from database import get_db
from auth import get_current_user

router = APIRouter(prefix="/inventory", tags=["Inventory"])

# ── Schemas ───────────────────────────────────────────────────────────────────

class InventoryCreate(BaseModel):
    product_id: str
    quantity: int = 1
    purchase_price: Optional[Decimal] = None
    asking_price: Optional[Decimal] = None
    minimum_price: Optional[Decimal] = None
    condition: Optional[str] = "NM"
    storage_location: Optional[str] = None
    box_number: Optional[str] = None
    notes: Optional[str] = None
    acquired_date: Optional[date] = None
    for_sale: bool = True

class InventoryUpdate(BaseModel):
    quantity: Optional[int] = None
    asking_price: Optional[Decimal] = None
    minimum_price: Optional[Decimal] = None
    current_market_price: Optional[Decimal] = None
    condition: Optional[str] = None
    storage_location: Optional[str] = None
    box_number: Optional[str] = None
    notes: Optional[str] = None
    for_sale: Optional[bool] = None
    featured: Optional[bool] = None

class InventoryResponse(BaseModel):
    """Enriched inventory item — includes card details for display"""
    inventory_id: str
    product_id: str

    # Card details (from tcg_details or card_details)
    card_name: Optional[str] = None
    game: Optional[str] = None          # e.g. "Pokemon", "Magic", "Hockey"
    set_name: Optional[str] = None
    card_number: Optional[str] = None
    image_url: Optional[str] = None
    rarity: Optional[str] = None
    is_foil: Optional[bool] = None
    # Sports specific
    player: Optional[str] = None
    team: Optional[str] = None
    year: Optional[int] = None
    rookie_card: Optional[bool] = None
    autograph: Optional[bool] = None
    graded: Optional[bool] = None
    grading_company: Optional[str] = None
    grade: Optional[str] = None

    # Inventory fields
    quantity: Optional[int] = None
    available_quantity: Optional[int] = None
    purchase_price: Optional[Decimal] = None
    asking_price: Optional[Decimal] = None
    minimum_price: Optional[Decimal] = None
    current_market_price: Optional[Decimal] = None
    condition: Optional[str] = None
    storage_location: Optional[str] = None
    box_number: Optional[str] = None
    notes: Optional[str] = None
    for_sale: Optional[bool] = None
    featured: Optional[bool] = None
    acquired_date: Optional[date] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True

class InventoryListResponse(BaseModel):
    items: List[InventoryResponse]
    total: int
    page: int
    page_size: int

# ── Helper — enrich inventory item with card details ─────────────────────────

def _enrich(item: models.Inventory, db: Session) -> InventoryResponse:
    """Attach card name, game, set, image etc from tcg/card detail tables."""
    base = InventoryResponse(
        inventory_id=item.inventory_id,
        product_id=item.product_id,
        quantity=item.quantity,
        available_quantity=item.available_quantity,
        purchase_price=item.purchase_price,
        asking_price=item.asking_price,
        minimum_price=item.minimum_price,
        current_market_price=item.current_market_price,
        condition=item.condition,
        storage_location=item.storage_location,
        box_number=item.box_number,
        notes=item.notes,
        for_sale=item.for_sale,
        featured=item.featured,
        acquired_date=item.acquired_date,
        created_at=item.created_at,
        updated_at=item.updated_at,
    )

    # Try TCG details first
    tcg = db.query(models.TcgDetail).filter(
        models.TcgDetail.product_id == item.product_id
    ).first()
    if tcg:
        # Look up set name
        set_name = None
        if tcg.set_id:
            s = db.query(models.Set).filter(models.Set.set_id == tcg.set_id).first()
            set_name = s.set_name if s else None

        base.card_name = tcg.card_name
        base.card_number = tcg.card_number
        base.image_url = tcg.image_url
        base.rarity = tcg.rarity
        base.is_foil = tcg.is_foil
        base.set_name = set_name

        # Determine game from category/element fields
        if tcg.element:
            base.game = "Final Fantasy TCG"
        elif tcg.pokemon_type or tcg.hp:
            base.game = "Pokemon"
        elif tcg.mana_cost or tcg.color:
            base.game = "Magic: The Gathering"
        else:
            base.game = tcg.category or "TCG"
        return base

    # Try sports card details
    sports = db.query(models.CardDetail).filter(
        models.CardDetail.product_id == item.product_id
    ).first()
    if sports:
        set_name = None
        if sports.set_id:
            s = db.query(models.Set).filter(models.Set.set_id == sports.set_id).first()
            set_name = s.set_name if s else None

        sport_name = None
        if sports.sport_id:
            sp = db.query(models.Sport).filter(models.Sport.sport_id == sports.sport_id).first()
            sport_name = sp.sport_name if sp else None

        base.card_name = sports.player
        base.player = sports.player
        base.team = sports.team
        base.year = sports.year
        base.card_number = sports.card_number
        base.set_name = set_name
        base.game = sport_name or "Sports"
        base.rookie_card = sports.rookie_card
        base.autograph = sports.autograph
        base.graded = sports.graded
        base.grading_company = sports.grading_company
        base.grade = sports.grade
        return base

    return base

# ── Endpoints ─────────────────────────────────────────────────────────────────

@router.get("/", response_model=InventoryListResponse)
def list_inventory(
    page: int = Query(1, ge=1),
    page_size: int = Query(50, ge=1, le=200),
    for_sale: Optional[bool] = None,
    condition: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """List all inventory items for the current user, enriched with card details."""
    query = db.query(models.Inventory).filter(
        models.Inventory.user_id == current_user.user_id
    )
    if for_sale is not None:
        query = query.filter(models.Inventory.for_sale == for_sale)
    if condition:
        query = query.filter(models.Inventory.condition == condition)

    total = query.count()
    items = query.order_by(
        models.Inventory.created_at.desc()
    ).offset((page - 1) * page_size).limit(page_size).all()

    return InventoryListResponse(
        items=[_enrich(item, db) for item in items],
        total=total,
        page=page,
        page_size=page_size
    )


@router.post("/", response_model=InventoryResponse, status_code=201)
def add_inventory(
    item: InventoryCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """Add a card to inventory."""
    import uuid
    db_item = models.Inventory(
        inventory_id=str(uuid.uuid4()),
        user_id=current_user.user_id,
        available_quantity=item.quantity,
        acquired_date=item.acquired_date or date.today(),
        **item.model_dump(exclude={"acquired_date"})
    )
    db.add(db_item)
    db.commit()
    db.refresh(db_item)
    return _enrich(db_item, db)


@router.get("/{inventory_id}", response_model=InventoryResponse)
def get_inventory_item(
    inventory_id: str,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """Get a single inventory item with card details."""
    item = db.query(models.Inventory).filter(
        models.Inventory.inventory_id == inventory_id,
        models.Inventory.user_id == current_user.user_id
    ).first()
    if not item:
        raise HTTPException(status_code=404, detail="Inventory item not found")
    return _enrich(item, db)


@router.put("/{inventory_id}", response_model=InventoryResponse)
def update_inventory_item(
    inventory_id: str,
    updates: InventoryUpdate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """Update an inventory item."""
    item = db.query(models.Inventory).filter(
        models.Inventory.inventory_id == inventory_id,
        models.Inventory.user_id == current_user.user_id
    ).first()
    if not item:
        raise HTTPException(status_code=404, detail="Inventory item not found")

    for field, value in updates.model_dump(exclude_unset=True).items():
        setattr(item, field, value)

    item.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(item)
    return _enrich(item, db)


@router.delete("/{inventory_id}", status_code=204)
def delete_inventory_item(
    inventory_id: str,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """Remove an inventory item."""
    item = db.query(models.Inventory).filter(
        models.Inventory.inventory_id == inventory_id,
        models.Inventory.user_id == current_user.user_id
    ).first()
    if not item:
        raise HTTPException(status_code=404, detail="Inventory item not found")
    db.delete(item)
    db.commit()
