import os
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.database import create_tables
from app.routers import auth, animals, proposals, policies, claims, vet, certificates, form_schemas, ai, audit_logs, fraud
from app.middleware.audit import AuditMiddleware


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: create tables
    await create_tables()
    # Create uploads dir
    os.makedirs("uploads", exist_ok=True)
    yield
    # Shutdown


app = FastAPI(
    title="XORA CattleShield 2.0 API",
    description="Digital Livestock Insurance Platform Backend",
    version="2.0.0",
    lifespan=lifespan,
)

# CORS - allow Flutter app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Audit trail middleware — logs all mutating API calls
app.add_middleware(AuditMiddleware)

# Static files for uploads
if os.path.exists("uploads"):
    app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

# Register routers under /api prefix
app.include_router(auth.router, prefix="/api")
app.include_router(animals.router, prefix="/api")
app.include_router(proposals.router, prefix="/api")
app.include_router(policies.router, prefix="/api")
app.include_router(claims.router, prefix="/api")
app.include_router(vet.router, prefix="/api")
app.include_router(certificates.router, prefix="/api")
app.include_router(form_schemas.router, prefix="/api")
app.include_router(ai.router, prefix="/api")
app.include_router(audit_logs.router, prefix="/api")
app.include_router(fraud.router, prefix="/api")


@app.get("/")
async def root():
    return {
        "name": "XORA CattleShield 2.0 API",
        "version": "2.0.0",
        "docs": "/docs",
    }


@app.get("/health")
async def health():
    return {"status": "ok"}
