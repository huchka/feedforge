import os

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.middleware import PrometheusMiddleware
from app.routers import articles, feeds, health, metrics

if os.getenv("DEBUG_PY") == "1":
    try:
        import debugpy

        debugpy.listen(("0.0.0.0", 5678))
    except ImportError:
        pass

app = FastAPI(title="FeedForge", version="0.1.0")

app.add_middleware(PrometheusMiddleware)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health.router, prefix="/api")
app.include_router(feeds.router, prefix="/api")
app.include_router(articles.router, prefix="/api")
app.include_router(metrics.router)
