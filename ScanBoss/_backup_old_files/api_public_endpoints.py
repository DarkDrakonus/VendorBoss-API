"""
VendorBoss API - Public Scanning Endpoints
No authentication required for scanning operations
Add these to your VendorBoss API to enable anonymous ScanBoss access
"""

from fastapi import APIRouter, HTTPException, Request, Depends
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime
from slowapi import Limiter
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

# Rate limiter (IP-based)
limiter = Limiter(key_func=get_remote_address)

# Router for public scanning endpoints
router = APIRouter(prefix="/api/scan", tags=["Public Scanner"])


# ============================================
# Request/Response Models
# ============================================

class FingerprintCheckRequest(BaseModel):
    fingerprint: str
    confidence_threshold: Optional[float] = 0.7


class CardDataModel(BaseModel):
    player_name: Optional[str]
    card_year: Optional[int]
    card_set: Optional[str]


class FingerprintSubmitRequest(BaseModel):
    fingerprint: str
    card_data: CardDataModel
    user_id: Optional[int] = None  # Always None for anonymous


# ============================================
# PUBLIC ENDPOINTS (No Auth Required)
# ============================================

@router.post("/fingerprint/check")
@limiter.limit("100/hour")  # 100 checks per hour per IP
async def check_fingerprint(
    request: Request,
    data: FingerprintCheckRequest,
    db=Depends(get_db)
):
    """
    PUBLIC: Check if a fingerprint is known
    
    Rate limit: 100 requests/hour per IP
    No authentication required
    """
    try:
        from learning_engine import CardLearningEngine
        
        engine = CardLearningEngine(db)
        result = engine.check_fingerprint(
            data.fingerprint,
            data.confidence_threshold
        )
        
        return {
            "known": result.get("known", False),
            "confidence": result.get("confidence", 0.0),
            "card_data": result.get("card_data")
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/fingerprint/submit")
@limiter.limit("50/hour")  # 50 submissions per hour per IP
async def submit_fingerprint(
    request: Request,
    data: FingerprintSubmitRequest,
    db=Depends(get_db)
):
    """
    PUBLIC: Submit card data for learning (anonymous)
    
    Rate limit: 50 submissions/hour per IP
    No authentication required
    All submissions are anonymous
    """
    try:
        from learning_engine import CardLearningEngine
        
        engine = CardLearningEngine(db)
        
        # Force anonymous submission
        card_data = data.card_data.dict()
        result = engine.submit_fingerprint(
            data.fingerprint,
            card_data,
            user_id=None  # Always anonymous
        )
        
        if result['success']:
            return {
                "success": True,
                "message": "Thank you for contributing!",
                "consensus": result['consensus']
            }
        else:
            raise HTTPException(status_code=400, detail=result['error'])
            
    except RateLimitExceeded:
        raise HTTPException(
            status_code=429,
            detail="Rate limit exceeded. Please try again later."
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/model/updates")
@limiter.limit("10/hour")  # 10 model updates per hour per IP
async def get_model_updates(
    request: Request,
    version: str = "1.0",
    last_update: Optional[str] = None,
    db=Depends(get_db)
):
    """
    PUBLIC: Get model updates for ScanBoss apps
    
    Rate limit: 10 requests/hour per IP
    No authentication required
    Returns list of high-confidence known cards
    """
    try:
        from learning_engine import CardLearningEngine
        
        engine = CardLearningEngine(db)
        
        # Check if update is needed
        latest_version = engine._get_latest_version()
        
        if version == latest_version and last_update:
            return {
                "update_available": False,
                "version": version,
                "known_cards": [],
                "total_count": 0
            }
        
        # Generate update package
        update = engine.generate_model_update(limit=10000)
        
        return {
            "update_available": True,
            "version": update['version'],
            "known_cards": update['known_cards'],
            "total_count": update['total_count'],
            "timestamp": update['created_at']
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/stats")
@limiter.limit("30/hour")  # 30 stats requests per hour per IP
async def get_learning_stats(request: Request, db=Depends(get_db)):
    """
    PUBLIC: Get system-wide learning statistics
    
    Rate limit: 30 requests/hour per IP
    No authentication required
    """
    try:
        from learning_engine import CardLearningEngine
        
        engine = CardLearningEngine(db)
        stats = engine.get_stats()
        
        return stats
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ============================================
# LEGACY PUBLIC ENDPOINTS (For Compatibility)
# ============================================

@router.post("/card-fingerprint")
@limiter.limit("100/hour")
async def legacy_scan_fingerprint(request: Request, db=Depends(get_db)):
    """
    LEGACY PUBLIC: Check card fingerprint (old format)
    
    Maintains compatibility with existing ScanBoss versions
    """
    try:
        body = await request.json()
        fingerprint = body.get('fingerprint', {}).get('hash')
        
        if not fingerprint:
            raise HTTPException(status_code=400, detail="Invalid fingerprint format")
        
        from learning_engine import CardLearningEngine
        engine = CardLearningEngine(db)
        result = engine.check_fingerprint(fingerprint)
        
        if result.get('known'):
            return {
                "found": True,
                "product": result.get('card_data')
            }
        else:
            return {
                "found": False
            }
            
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ============================================
# ADMIN ENDPOINTS (Protected - Keep Auth)
# ============================================

@router.post("/admin/model/generate")
async def generate_model(
    version: Optional[str] = None,
    current_user = Depends(get_current_admin),  # Admin only
    db=Depends(get_db)
):
    """
    ADMIN ONLY: Manually trigger model generation
    
    Requires admin authentication
    """
    try:
        from learning_engine import CardLearningEngine
        
        engine = CardLearningEngine(db)
        update = engine.generate_model_update(version=version)
        
        return {
            "success": True,
            "version": update['version'],
            "card_count": update['total_count']
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/admin/fingerprint/{fingerprint}")
async def get_fingerprint_details(
    fingerprint: str,
    current_user = Depends(get_current_admin),  # Admin only
    db=Depends(get_db)
):
    """
    ADMIN ONLY: Get detailed fingerprint information
    
    Shows all submissions and consensus details
    Requires admin authentication
    """
    try:
        query = """
            SELECT * FROM card_fingerprints
            WHERE fingerprint = %s
        """
        fp_data = db.execute(query, (fingerprint,)).fetchone()
        
        if not fp_data:
            raise HTTPException(status_code=404, detail="Fingerprint not found")
        
        submissions_query = """
            SELECT 
                submitted_player_name,
                submitted_card_year,
                submitted_card_set,
                created_at,
                user_id
            FROM fingerprint_submissions
            WHERE fingerprint = %s
            ORDER BY created_at DESC
        """
        submissions = db.execute(submissions_query, (fingerprint,)).fetchall()
        
        return {
            "fingerprint": dict(fp_data),
            "submissions": [dict(s) for s in submissions]
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ============================================
# Rate Limit Error Handler
# ============================================

@router.exception_handler(RateLimitExceeded)
async def rate_limit_handler(request: Request, exc: RateLimitExceeded):
    """Custom error message for rate limits"""
    return {
        "error": "Rate limit exceeded",
        "message": "You're making too many requests. Please wait a bit and try again.",
        "retry_after": "1 hour"
    }


# ============================================
# Health Check (Public)
# ============================================

@router.get("/health")
async def health_check():
    """
    PUBLIC: API health check
    
    No rate limit, no authentication
    """
    return {
        "status": "healthy",
        "service": "VendorBoss Scanner API",
        "public_access": True,
        "timestamp": datetime.now().isoformat()
    }
