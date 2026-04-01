"""Feed fetcher — parses RSS/Atom feeds, inserts new articles, queues for summarization."""

import logging
import socket
import time
from datetime import UTC, datetime, timedelta

import feedparser
import redis
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError

from app.config import settings
from app.database import SessionLocal
from app.models.article import Article
from app.models.feed import Feed

logger = logging.getLogger(__name__)

QUEUE_KEY = "feedforge:articles:pending"


def get_redis() -> redis.Redis:
    return redis.Redis(
        host=settings.redis_host,
        port=settings.redis_port,
        db=settings.redis_db,
        decode_responses=True,
    )


def get_due_feeds(db) -> list[Feed]:
    """Return active feeds that are due for a refresh."""
    now = datetime.now(UTC)
    stmt = (
        select(Feed)
        .where(Feed.is_active.is_(True))
        .where(
            (Feed.last_fetched_at.is_(None))
            | (Feed.last_fetched_at + timedelta(minutes=1) * Feed.fetch_interval_minutes < now)
        )
    )
    return list(db.scalars(stmt).all())


def _parse_published(entry) -> datetime | None:
    parsed = getattr(entry, "published_parsed", None)
    if parsed is None:
        return None
    try:
        return datetime(*parsed[:6], tzinfo=UTC)
    except (TypeError, ValueError):
        return None


def _extract_content(entry) -> str | None:
    """Get the best available content from a feed entry."""
    # feedparser puts full content in entry.content[0].value when available
    content_list = getattr(entry, "content", None)
    if content_list:
        return content_list[0].get("value")
    return getattr(entry, "summary", None)


def _update_feed_metadata(feed: Feed, parsed) -> None:
    """Populate feed title/site_url/feed_type from parsed data on first fetch."""
    feed_info = parsed.get("feed", {})
    if not feed.title and feed_info.get("title"):
        feed.title = feed_info["title"]
    if not feed.site_url and feed_info.get("link"):
        feed.site_url = feed_info["link"]
    if not feed.feed_type and parsed.get("version"):
        feed.feed_type = parsed["version"]


def fetch_feed(feed: Feed, db, redis_client: redis.Redis | None) -> int:
    """Fetch a single feed, insert new articles, push IDs to Redis queue.

    Returns the number of new articles inserted.
    """
    parsed = feedparser.parse(feed.url)

    if parsed.bozo and not parsed.entries:
        logger.warning("Feed %s failed to parse: %s", feed.url, parsed.bozo_exception)
        return 0

    _update_feed_metadata(feed, parsed)

    new_count = 0
    now = datetime.now(UTC)

    for entry in parsed.entries:
        link = getattr(entry, "link", None)
        title = getattr(entry, "title", None)
        if not link or not title:
            continue

        article = Article(
            feed_id=feed.id,
            url=link[:2048],
            title=title[:1000],
            author=getattr(entry, "author", None),
            content=_extract_content(entry),
            published_at=_parse_published(entry),
            fetched_at=now,
        )

        nested = db.begin_nested()
        try:
            db.add(article)
            db.flush()
            new_count += 1

            if redis_client is not None:
                try:
                    redis_client.lpush(QUEUE_KEY, str(article.id))
                except redis.RedisError:
                    logger.warning("Failed to push article %s to Redis queue", article.id)
        except IntegrityError:
            nested.rollback()

    feed.last_fetched_at = now
    db.commit()
    return new_count


def main() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )

    logger.info("Feed fetcher starting")
    socket.setdefaulttimeout(30)
    start = time.monotonic()

    db = SessionLocal()
    try:
        redis_client: redis.Redis | None = None
        try:
            redis_client = get_redis()
            redis_client.ping()
            logger.info("Connected to Redis at %s:%s", settings.redis_host, settings.redis_port)
        except redis.RedisError:
            logger.warning("Redis unavailable — articles will be inserted but not queued")
            redis_client = None

        feeds = get_due_feeds(db)
        logger.info("Found %d feeds due for refresh", len(feeds))

        total_new = 0
        for feed in feeds:
            try:
                count = fetch_feed(feed, db, redis_client)
                total_new += count
                logger.info("Feed %s: %d new articles", feed.url, count)
            except Exception:
                logger.exception("Error fetching feed %s", feed.url)
                db.rollback()

        elapsed = time.monotonic() - start
        logger.info("Fetcher complete: %d feeds processed, %d new articles (%.1fs)", len(feeds), total_new, elapsed)
    finally:
        db.close()


if __name__ == "__main__":
    main()
