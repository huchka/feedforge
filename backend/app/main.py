from fastapi import FastAPI

from app.routers import articles, feeds, health

app = FastAPI(title="FeedForge", version="0.1.0")

app.include_router(health.router, prefix="/api")
app.include_router(feeds.router, prefix="/api")
app.include_router(articles.router, prefix="/api")
