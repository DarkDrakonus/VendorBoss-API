"""
Expenses endpoints
Track show and business expenses
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

router = APIRouter(prefix="/expenses", tags=["Expenses"])

# ── Schemas ───────────────────────────────────────────────────────────────────

class ExpenseCreate(BaseModel):
    show_id: Optional[str] = None
    expense_type: str          # "table_fee", "travel", "supplies", "food", "other"
    description: str
    amount: Decimal
    payment_method: Optional[str] = "cash"
    notes: Optional[str] = None
    expense_date: Optional[date] = None

class ExpenseUpdate(BaseModel):
    expense_type: Optional[str] = None
    description: Optional[str] = None
    amount: Optional[Decimal] = None
    payment_method: Optional[str] = None
    notes: Optional[str] = None
    expense_date: Optional[date] = None

class ExpenseResponse(BaseModel):
    expense_id: str
    show_id: Optional[str]
    expense_type: str
    description: str
    amount: Decimal
    payment_method: Optional[str]
    notes: Optional[str]
    expense_date: date
    created_at: Optional[datetime]

    class Config:
        from_attributes = True

class ExpenseListResponse(BaseModel):
    items: List[ExpenseResponse]
    total: int
    total_amount: Decimal

# ── Expense type constants (for reference in Swagger) ─────────────────────────
EXPENSE_TYPES = [
    "table_fee",
    "travel",
    "fuel",
    "hotel",
    "food",
    "supplies",
    "bags_sleeves",
    "display",
    "shipping",
    "other"
]

# ── Endpoints ─────────────────────────────────────────────────────────────────

@router.get("/types", tags=["Expenses"])
def get_expense_types():
    """Get list of valid expense type values."""
    return {"expense_types": EXPENSE_TYPES}


@router.get("/", response_model=ExpenseListResponse)
def list_expenses(
    show_id: Optional[str] = None,
    expense_type: Optional[str] = None,
    date_from: Optional[date] = None,
    date_to: Optional[date] = None,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """List expenses for the current user."""
    query = db.query(models.Expense).filter(
        models.Expense.user_id == current_user.user_id
    )

    if show_id:
        query = query.filter(models.Expense.show_id == show_id)
    if expense_type:
        query = query.filter(models.Expense.expense_type == expense_type)
    if date_from:
        query = query.filter(models.Expense.expense_date >= date_from)
    if date_to:
        query = query.filter(models.Expense.expense_date <= date_to)

    total = query.count()
    total_amount = db.query(
        func.coalesce(func.sum(models.Expense.amount), 0)
    ).filter(
        models.Expense.user_id == current_user.user_id
    ).scalar()

    items = query.order_by(models.Expense.expense_date.desc()).all()

    return ExpenseListResponse(
        items=items,
        total=total,
        total_amount=Decimal(str(total_amount))
    )


@router.post("/", response_model=ExpenseResponse, status_code=201)
def add_expense(
    expense: ExpenseCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """Add an expense."""
    # Verify show belongs to user if provided
    if expense.show_id:
        show = db.query(models.Show).filter(
            models.Show.show_id == expense.show_id,
            models.Show.user_id == current_user.user_id
        ).first()
        if not show:
            raise HTTPException(status_code=404, detail="Show not found")

    db_expense = models.Expense(
        expense_id=str(uuid.uuid4()),
        user_id=current_user.user_id,
        expense_date=expense.expense_date or date.today(),
        **expense.model_dump(exclude={"expense_date"})
    )
    db.add(db_expense)
    db.commit()
    db.refresh(db_expense)
    return db_expense


@router.put("/{expense_id}", response_model=ExpenseResponse)
def update_expense(
    expense_id: str,
    updates: ExpenseUpdate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """Update an expense."""
    expense = db.query(models.Expense).filter(
        models.Expense.expense_id == expense_id,
        models.Expense.user_id == current_user.user_id
    ).first()

    if not expense:
        raise HTTPException(status_code=404, detail="Expense not found")

    for field, value in updates.model_dump(exclude_unset=True).items():
        setattr(expense, field, value)

    db.commit()
    db.refresh(expense)
    return expense


@router.delete("/{expense_id}", status_code=204)
def delete_expense(
    expense_id: str,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """Delete an expense."""
    expense = db.query(models.Expense).filter(
        models.Expense.expense_id == expense_id,
        models.Expense.user_id == current_user.user_id
    ).first()

    if not expense:
        raise HTTPException(status_code=404, detail="Expense not found")

    db.delete(expense)
    db.commit()
