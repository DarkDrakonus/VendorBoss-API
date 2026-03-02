"""
Inventory endpoints
CRUD for a vendor's card inventory
"""
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import or_
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
    inventory_id: str
    product_id: str
    quantity: int
    available_quantity: Optional[int]
    purchase_price: Optional[Decimal]
    asking_price: Optional[Decimal]
    minimum_price: Optional[Decimal]
    current_market_price: Optional[Decimal]
    condition: Optional[str]
    storage_location: Optional[str]
    box_number: Optional[str]
    notes: Optional[str]
    for_sale: Optional[bool]
    featured: Optional[bool]
    acquired_date: Optional[date]
    created_at: Optional[datetime]
    updated_at: Optional[datetime]

    class Config:
        from_attributes = True

class InventoryListResponse(BaseModel):
    items: List[InventoryResponse]
    total: int
    page: int
    page_size: int

# ── Endpoints ─────────────────────────────────────────────────────────────────

@router.get("/", response_model=InventoryListResponse)
def list_inventory(
    page: int = Query(1, ge=1),
    page_size: int = Query(50, ge=1, le=200),
    for_sale: Optional[bool] = None,
    condition: Optional[str] = None,
    search: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """List all inventory items for the current user."""
    query = db.query(models.Inventory).filter(
        models.Inventory.user_id == current_user.user_id
    )

    if for_sale is not None:
        query = query.filter(models.Inventory.for_sale == for_sale)
    if condition:
        query = query.filter(models.Inventory.condition == condition)

    total = query.count()
    items = query.offset((page - 1) * page_size).limit(page_size).all()

    return InventoryListResponse(
        items=items,
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
    return db_item


@router.get("/{inventory_id}", response_model=InventoryResponse)
def get_inventory_item(
    inventory_id: str,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """Get a single inventory item."""
    item = db.query(models.Inventory).filter(
        models.Inventory.inventory_id == inventory_id,
        models.Inventory.user_id == current_user.user_id
    ).first()

    if not item:
        raise HTTPException(status_code=404, detail="Inventory item not found")
    return item


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
    return item


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
