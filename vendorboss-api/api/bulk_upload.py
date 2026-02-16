"""
Bulk upload endpoint for local development
No authentication required
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from datetime import datetime
from typing import List, Dict
from pydantic import BaseModel, Field

import models
from database import get_db

router = APIRouter(prefix="/api/bulk", tags=["Bulk Upload"])

class FingerprintComponents(BaseModel):
    """Individual fingerprint components - FLEXIBLE length for compatibility"""
    border: str
    name_region: str
    color_zones: str
    texture: str
    layout: str
    quadrant_0_0: str
    quadrant_0_1: str
    quadrant_0_2: str
    quadrant_1_0: str
    quadrant_1_1: str
    quadrant_1_2: str
    quadrant_2_0: str
    quadrant_2_1: str
    quadrant_2_2: str

class BulkFingerprintRequest(BaseModel):
    """Bulk fingerprint upload - no auth for local dev"""
    fingerprint_hash: str = Field(..., min_length=32, max_length=64)
    components: FingerprintComponents
    product_id: str
    verified: bool = True

def pad_hash(hash_str: str, target_length: int = 64) -> str:
    """Pad short hashes to target length by repeating"""
    if len(hash_str) >= target_length:
        return hash_str[:target_length]
    
    # Repeat the hash to reach target length
    repeats = (target_length // len(hash_str)) + 1
    padded = (hash_str * repeats)[:target_length]
    return padded

@router.post("/fingerprints", status_code=201)
def bulk_upload_fingerprint(
    request: BulkFingerprintRequest,
    db: Session = Depends(get_db)
):
    """
    Bulk upload fingerprints - NO AUTHENTICATION
    For local development and initial database seeding only!
    """
    
    # Check if fingerprint already exists
    existing = db.query(models.CardFingerprint).filter(
        models.CardFingerprint.fingerprint_hash == request.fingerprint_hash
    ).first()
    
    if existing:
        # Update if it's the same product
        if existing.product_id == request.product_id:
            existing.times_matched += 1
            existing.verified = True
            db.commit()
            return {
                "success": True,
                "message": "Fingerprint updated",
                "fingerprint_id": str(existing.fingerprint_id),
                "status": "updated"
            }
        else:
            # Conflict - different card with same fingerprint
            raise HTTPException(status_code=409, detail="Fingerprint exists for different product")
    
    # Create product if it doesn't exist
    product = db.query(models.Product).filter(
        models.Product.product_id == request.product_id
    ).first()
    
    if not product:
        # Create minimal product entry
        product = models.Product(
            product_id=request.product_id,
            product_type_id='tcg_card',  # Assuming FFTCG
            created_at=datetime.utcnow(),
            updated_at=datetime.utcnow()
        )
        db.add(product)
        db.flush()  # Get the ID without committing
    
    # Pad all component hashes to 64 chars
    components = request.components
    
    # Build raw_components dict
    raw_components = {
        "border": components.border,
        "name_region": components.name_region,
        "color_zones": components.color_zones,
        "texture": components.texture,
        "layout": components.layout,
        "quadrant_0_0": components.quadrant_0_0,
        "quadrant_0_1": components.quadrant_0_1,
        "quadrant_0_2": components.quadrant_0_2,
        "quadrant_1_0": components.quadrant_1_0,
        "quadrant_1_1": components.quadrant_1_1,
        "quadrant_1_2": components.quadrant_1_2,
        "quadrant_2_0": components.quadrant_2_0,
        "quadrant_2_1": components.quadrant_2_1,
        "quadrant_2_2": components.quadrant_2_2
    }
    
    # Create fingerprint with padded hashes
    new_fp = models.CardFingerprint(
        product_id=request.product_id,
        fingerprint_hash=pad_hash(request.fingerprint_hash),
        border=pad_hash(components.border),
        name_region=pad_hash(components.name_region),
        color_zones=pad_hash(components.color_zones),
        texture=pad_hash(components.texture),
        layout=pad_hash(components.layout),
        quadrant_0_0=pad_hash(components.quadrant_0_0),
        quadrant_0_1=pad_hash(components.quadrant_0_1),
        quadrant_0_2=pad_hash(components.quadrant_0_2),
        quadrant_1_0=pad_hash(components.quadrant_1_0),
        quadrant_1_1=pad_hash(components.quadrant_1_1),
        quadrant_1_2=pad_hash(components.quadrant_1_2),
        quadrant_2_0=pad_hash(components.quadrant_2_0),
        quadrant_2_1=pad_hash(components.quadrant_2_1),
        quadrant_2_2=pad_hash(components.quadrant_2_2),
        raw_components=raw_components,  # Store original hashes
        verified=request.verified,
        auto_generated=False,
        confidence_score=1.0,
        times_matched=1,
        last_matched_at=datetime.utcnow()
    )
    
    db.add(new_fp)
    db.commit()
    db.refresh(new_fp)
    
    return {
        "success": True,
        "message": "Fingerprint created",
        "fingerprint_id": str(new_fp.fingerprint_id),
        "status": "created"
    }
