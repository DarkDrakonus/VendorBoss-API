"""
VendorBoss 2.0 API
Inventory and show management for TCG/sports card vendors
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from database import init_db

# Import routers
from auth import router as auth_router
from api.inventory import router as inventory_router
from api.shows import router as shows_router
from api.sales import router as sales_router
from api.expenses import router as expenses_router

from api.reports import router as reports_router

from api.cards import router as cards_router
from api.scan import router as scan_router

app = FastAPI(
    title="VendorBoss API",
    description="Inventory and show management for card vendors",
    version="2.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router)
app.include_router(inventory_router)
app.include_router(shows_router)
app.include_router(sales_router)
app.include_router(expenses_router)
app.include_router(reports_router)
app.include_router(cards_router)
app.include_router(scan_router)

@app.on_event("startup")
def startup_event():
    init_db()

@app.get("/", tags=["Health"])
def root():
    return {
        "name": "VendorBoss API",
        "version": "2.0.0",
        "status": "running",
        "docs": "/docs"
    }
