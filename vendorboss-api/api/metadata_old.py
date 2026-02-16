"""
Metadata API endpoints for FFTCG
Provides sets, elements, rarities for ScanBoss dropdowns
"""
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from typing import List
from pydantic import BaseModel

import models
from database import get_db

router = APIRouter(prefix="/api", tags=["Metadata"])

# ============================================================================
# PYDANTIC SCHEMAS
# ============================================================================

class SetInfo(BaseModel):
    """FFTCG Set information"""
    set_id: str
    set_name: str
    set_year: int
    series: str

class SetListResponse(BaseModel):
    """Response for sets list"""
    sets: List[SetInfo]

class ElementListResponse(BaseModel):
    """Response for elements list"""
    elements: List[str]

class RarityListResponse(BaseModel):
    """Response for rarities list"""
    rarities: List[str]

# ============================================================================
# ENDPOINTS
# ============================================================================

@router.get("/sets", response_model=SetListResponse)
def get_sets(db: Session = Depends(get_db)):
    """
    Get all FFTCG sets for ScanBoss dropdowns
    Returns sets ordered by year (newest first)
    """
    sets = db.query(models.Set).order_by(models.Set.set_year.desc()).all()
    
    return SetListResponse(
        sets=[
            SetInfo(
                set_id=s.set_id,
                set_name=s.set_name,
                set_year=s.set_year,
                series=s.series
            )
            for s in sets
        ]
    )

@router.get("/elements", response_model=ElementListResponse)
def get_elements():
    """
    Get all FFTCG elements
    Standard elements for Final Fantasy TCG
    """
    return ElementListResponse(
        elements=[
            "Fire",
            "Ice", 
            "Wind",
            "Earth",
            "Lightning",
            "Water",
            "Light",
            "Dark"
        ]
    )

@router.get("/rarities", response_model=RarityListResponse)
def get_rarities():
    """
    Get all FFTCG rarities
    Standard rarity levels for Final Fantasy TCG
    """
    return RarityListResponse(
        rarities=[
            "Common",
            "Rare",
            "Hero",
            "Legend",
            "Starter",
            "Promo",
            "Special"
        ]
    )
