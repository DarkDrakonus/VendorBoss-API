"""
Sales endpoints
Record and manage sales transactions
"""
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import func
from typing import Optional, List
from datetime import date, datetime
from decimal import Decimal
from pydantic import BaseModel
import uuid

import models
from database import get_db
from auth import get_current_user

router = APIRouter(prefix="/sales", tags=["Sales"])

# ── Schemas ───────────────────────────────────────────────────────────────────

class SaleCreate(BaseModel):
    inventory_id: str
    quantity: int = 1
    unit_price: Decimal
    payment_method: Optional[str] = "cash"
    payment_reference: Optional[str] = None
    customer_name: Optional[str] = None
    customer_email: Optional[str] = None
    customer_phone: Optional[str] = None
    show_id: Optional[str] = None   # looked up to get show_name/date
    notes: Optional[str] = None
    transaction_date: Optional[datetime] = None

class SaleResponse(BaseModel):
    transaction_id: str
    inventory_id: str
    quantity: int
    unit_price: Decimal
    total_amount: Decimal
    payment_method: Optional[str]
    payment_reference: Optional[str]
    customer_name: Optional[str]
    customer_email: Optional[str]
    customer_phone: Optional[str]
    show_name: Optional[str]
    show_date: Optional[date]
    show_location: Optional[str]
    notes: Optional[str]
    transaction_date: datetime
    created_at: Optional[datetime]

    class Config:
        from_attributes = True

class SaleListResponse(BaseModel):
    items: List[SaleResponse]
    total: int
    total_revenue: Decimal
    page: int
    page_size: int

# ── Endpoints ─────────────────────────────────────────────────────────────────

@router.get("/", response_model=SaleListResponse)
def list_sales(
    page: int = Query(1, ge=1),
    page_size: int = Query(50, ge=1, le=200),
    show_id: Optional[str] = None,
    date_from: Optional[date] = None,
    date_to: Optional[date] = None,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """List all sales transactions for the current user."""
    query = db.query(models.InventoryTransaction).filter(
        models.InventoryTransaction.user_id == current_user.user_id,
        models.InventoryTransaction.transaction_type == "sale"
    )

    # Filter by show
    if show_id:
        show = db.query(models.Show).filter(
            models.Show.show_id == show_id,
            models.Show.user_id == current_user.user_id
        ).first()
        if show:
            query = query.filter(
                models.InventoryTransaction.show_name == show.show_name
            )

    if date_from:
        query = query.filter(models.InventoryTransaction.transaction_date >= date_from)
    if date_to:
        query = query.filter(models.InventoryTransaction.transaction_date <= date_to)

    total = query.count()
    total_revenue = db.query(
        func.coalesce(func.sum(models.InventoryTransaction.total_amount), 0)
    ).filter(
        models.InventoryTransaction.user_id == current_user.user_id,
        models.InventoryTransaction.transaction_type == "sale"
    ).scalar()

    items = query.order_by(
        models.InventoryTransaction.transaction_date.desc()
    ).offset((page - 1) * page_size).limit(page_size).all()

    return SaleListResponse(
        items=items,
        total=total,
        total_revenue=Decimal(str(total_revenue)),
        page=page,
        page_size=page_size
    )


@router.post("/", response_model=SaleResponse, status_code=201)
def record_sale(
    sale: SaleCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """Record a sale transaction."""
    # Verify inventory item belongs to user and has enough stock
    inv_item = db.query(models.Inventory).filter(
        models.Inventory.inventory_id == sale.inventory_id,
        models.Inventory.user_id == current_user.user_id
    ).first()

    if not inv_item:
        raise HTTPException(status_code=404, detail="Inventory item not found")

    available = inv_item.available_quantity or inv_item.quantity or 0
    if available < sale.quantity:
        raise HTTPException(
            status_code=400,
            detail=f"Not enough stock — available: {available}, requested: {sale.quantity}"
        )

    # Look up show details if show_id provided
    show_name = None
    show_date = None
    show_location = None
    if sale.show_id:
        show = db.query(models.Show).filter(
            models.Show.show_id == sale.show_id,
            models.Show.user_id == current_user.user_id
        ).first()
        if show:
            show_name = show.show_name
            show_date = show.show_date
            show_location = show.location

    total_amount = sale.unit_price * sale.quantity

    transaction = models.InventoryTransaction(
        transaction_id=str(uuid.uuid4()),
        inventory_id=sale.inventory_id,
        user_id=current_user.user_id,
        transaction_type="sale",
        quantity=sale.quantity,
        unit_price=sale.unit_price,
        total_amount=total_amount,
        payment_method=sale.payment_method,
        payment_reference=sale.payment_reference,
        customer_name=sale.customer_name,
        customer_email=sale.customer_email,
        customer_phone=sale.customer_phone,
        show_name=show_name,
        show_date=show_date,
        show_location=show_location,
        notes=sale.notes,
        transaction_date=sale.transaction_date or datetime.utcnow(),
    )

    # Decrement available quantity
    inv_item.available_quantity = available - sale.quantity
    inv_item.updated_at = datetime.utcnow()

    db.add(transaction)
    db.commit()
    db.refresh(transaction)
    return transaction


@router.get("/{transaction_id}", response_model=SaleResponse)
def get_sale(
    transaction_id: str,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """Get a single sale transaction."""
    transaction = db.query(models.InventoryTransaction).filter(
        models.InventoryTransaction.transaction_id == transaction_id,
        models.InventoryTransaction.user_id == current_user.user_id,
        models.InventoryTransaction.transaction_type == "sale"
    ).first()

    if not transaction:
        raise HTTPException(status_code=404, detail="Transaction not found")
    return transaction


@router.delete("/{transaction_id}", status_code=204)
def void_sale(
    transaction_id: str,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """Void a sale — restores inventory quantity."""
    transaction = db.query(models.InventoryTransaction).filter(
        models.InventoryTransaction.transaction_id == transaction_id,
        models.InventoryTransaction.user_id == current_user.user_id,
        models.InventoryTransaction.transaction_type == "sale"
    ).first()

    if not transaction:
        raise HTTPException(status_code=404, detail="Transaction not found")

    # Restore inventory
    inv_item = db.query(models.Inventory).filter(
        models.Inventory.inventory_id == transaction.inventory_id
    ).first()
    if inv_item:
        inv_item.available_quantity = (inv_item.available_quantity or 0) + transaction.quantity
        inv_item.updated_at = datetime.utcnow()

    db.delete(transaction)
    db.commit()
