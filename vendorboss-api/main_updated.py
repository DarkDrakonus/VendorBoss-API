"""
VendorBoss 2.0 API
Card identification and inventory management using visual fingerprinting
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from database import init_db

# Import routers
from auth import router as auth_router
from api.fingerprints import router as fingerprints_router
from api.metadata import router as metadata_router
from api.bulk_upload import router as bulk_upload_router

# App Initialization
app = FastAPI(
    title="VendorBoss 2.0 API",
    description="Card identification using visual fingerprinting - Starting with Final Fantasy TCG",
    version="2.0.0"
)

# CORS - Allow all origins in development (restrict in production)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(auth_router)
app.include_router(fingerprints_router)
app.include_router(metadata_router)
app.include_router(bulk_upload_router)  # NEW: Bulk upload for local dev

@app.on_event("startup")
def startup_event():
    """Initialize database on startup"""
    init_db()

@app.get("/")
def root():
    """API root endpoint"""
    return {
        "name": "VendorBoss 2.0 API",
        "version": "2.0.0",
        "status": "active",
        "docs": "/docs",
        "focus": "Final Fantasy Trading Card Game"
    }
