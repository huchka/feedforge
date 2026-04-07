import logging

import redis
from prometheus_client import Counter, Gauge, Histogram
from sqlalchemy import func, select

from app.config import settings
from app.database import SessionLocal
from app.models.article import Article
from app.models.feed import Feed

logger = logging.getLogger(__name__)

# --- HTTP metrics ---

REQUEST_COUNT = Counter(
    "feedforge_http_requests_total",
    "Total HTTP requests",
    ["method", "endpoint", "status_code"],
)

REQUEST_LATENCY = Histogram(
    "feedforge_http_request_duration_seconds",
    "HTTP request duration in seconds",
    ["method", "endpoint"],
)

REQUESTS_IN_PROGRESS = Gauge(
    "feedforge_http_requests_in_progress",
    "Number of HTTP requests currently being processed",
    ["method"],
)

# --- Business metrics ---

FEEDS_TOTAL = Gauge("feedforge_feeds_total", "Total number of registered feeds")
FEEDS_ACTIVE = Gauge("feedforge_feeds_active", "Number of active feeds")
ARTICLES_TOTAL = Gauge("feedforge_articles_total", "Total articles fetched")
ARTICLES_SUMMARIZED = Gauge("feedforge_articles_summarized", "Articles with AI summaries")
ARTICLES_DIGEST_SENT = Gauge("feedforge_articles_digest_sent", "Articles sent via digest")
QUEUE_LENGTH = Gauge("feedforge_queue_length", "Articles waiting in Redis queue")

QUEUE_KEY = "feedforge:articles:pending"


def collect_business_metrics() -> None:
    """Query PostgreSQL and Redis to update business metric gauges."""
    try:
        db = SessionLocal()
        try:
            FEEDS_TOTAL.set(db.scalar(select(func.count()).select_from(Feed)) or 0)
            FEEDS_ACTIVE.set(
                db.scalar(select(func.count()).select_from(Feed).where(Feed.is_active.is_(True))) or 0
            )
            ARTICLES_TOTAL.set(db.scalar(select(func.count()).select_from(Article)) or 0)
            ARTICLES_SUMMARIZED.set(
                db.scalar(
                    select(func.count()).select_from(Article).where(Article.summary.is_not(None))
                ) or 0
            )
            ARTICLES_DIGEST_SENT.set(
                db.scalar(
                    select(func.count()).select_from(Article).where(Article.digest_sent_at.is_not(None))
                ) or 0
            )
        finally:
            db.close()
    except Exception:
        logger.warning("Failed to collect DB metrics", exc_info=True)

    try:
        r = redis.Redis(
            host=settings.redis_host, port=settings.redis_port, db=settings.redis_db,
        )
        QUEUE_LENGTH.set(r.llen(QUEUE_KEY))
        r.close()
    except Exception:
        logger.warning("Failed to collect Redis metrics", exc_info=True)
