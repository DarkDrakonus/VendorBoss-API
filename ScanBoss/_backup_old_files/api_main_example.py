"""
VendorBoss API - Main Application Setup
This shows how to integrate the public scanning endpoints
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

# Import your existing routers
# from your_existing_routes import products_router, auth_router, etc.

# Import new public scanning components
from api_config import setup_public_api
from api_public_endpoints import router as public_scanner_router


# ============================================
# Create FastAPI Application
# ============================================

app = FastAPI(
    title="VendorBoss API",
    description="Card inventory and scanning system with public access",
    version="2.0.0"
)


# ============================================
# Setup Public API Features
# ============================================

# Configure CORS, rate limiting, logging
setup_public_api(app)


# ============================================
# Register Routers
# ============================================

# PUBLIC SCANNER ROUTES (No Auth)
app.include_router(
    public_scanner_router,
    tags=["Public Scanner"]
)

# YOUR EXISTING ROUTES (Keep as-is)
# app.include_router(products_router)
# app.include_router(auth_router)
# app.include_router(inventory_router)
# etc.


# ============================================
# Root Endpoint
# ============================================

@app.get("/")
async def root():
    """API information"""
    return {
        "name": "VendorBoss API",
        "version": "2.0.0",
        "features": {
            "public_scanning": True,
            "fleet_learning": True,
            "authentication": "optional"
        },
        "endpoints": {
            "docs": "/docs",
            "scanner": "/api/scan",
            "health": "/api/scan/health"
        }
    }


@app.get("/health")
async def health():
    """Health check"""
    return {
        "status": "healthy",
        "timestamp": "2024-01-15T12:00:00Z"
    }


# ============================================
# For Running Locally
# ============================================

if __name__ == "__main__":
    import uvicorn
    
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        log_level="info"
    )
