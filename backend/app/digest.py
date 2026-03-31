"""Daily digest — queries recent articles and sends a summary notification."""

import logging
import sys
import time
from collections import defaultdict
from datetime import UTC, datetime, timedelta

import httpx
from sqlalchemy import func, select
from sqlalchemy.orm import joinedload

from app.config import settings
from app.database import SessionLocal
from app.models.article import Article

logger = logging.getLogger(__name__)

LINE_PUSH_URL = "https://api.line.me/v2/bot/message/push"
LINE_TEXT_LIMIT = 5000


def count_recent_articles(db) -> int:
    """Return total article count from the last N hours (regardless of summary status)."""
    cutoff = datetime.now(UTC) - timedelta(hours=settings.digest_lookback_hours)
    stmt = select(func.count(Article.id)).where(Article.fetched_at >= cutoff)
    return db.scalar(stmt) or 0


def get_recent_articles(db) -> list[Article]:
    """Return articles with summaries from the last N hours."""
    cutoff = datetime.now(UTC) - timedelta(hours=settings.digest_lookback_hours)
    stmt = (
        select(Article)
        .options(joinedload(Article.feed))
        .where(Article.fetched_at >= cutoff)
        .where(Article.summary.is_not(None))
        .order_by(Article.feed_id, Article.published_at.desc())
    )
    return list(db.scalars(stmt).unique().all())


def format_digest(articles: list[Article]) -> str:
    """Format articles into a plain-text digest grouped by feed."""
    by_feed: dict[str, list[Article]] = defaultdict(list)
    for article in articles:
        feed_title = article.feed.title or article.feed.url
        by_feed[feed_title].append(article)

    today = datetime.now(UTC).strftime("%Y-%m-%d")
    lines = [f"FeedForge Daily Digest — {today}", f"{len(articles)} articles from {len(by_feed)} feeds", ""]

    for feed_title, feed_articles in by_feed.items():
        lines.append(f"== {feed_title} ==")
        for a in feed_articles:
            lines.append(f"  {a.title}")
            if a.summary:
                lines.append(f"  {a.summary}")
            lines.append(f"  {a.url}")
            lines.append("")
    return "\n".join(lines)


def _send_slack(text: str, total_articles: int) -> None:
    resp = httpx.post(settings.digest_webhook_url, json={"text": text}, timeout=30)
    resp.raise_for_status()
    logger.info("Slack notification sent (%d chars, %d articles)", len(text), total_articles)


def _send_line(text: str, total_articles: int) -> None:
    if len(text) > LINE_TEXT_LIMIT:
        truncated_at = text.rfind("\n", 0, LINE_TEXT_LIMIT - 60)
        if truncated_at == -1:
            truncated_at = LINE_TEXT_LIMIT - 60
        text = text[:truncated_at] + "\n\n... (truncated, see app for full list)"
        logger.warning(
            "LINE message truncated: %d chars -> %d chars (limit %d)",
            len(text), truncated_at, LINE_TEXT_LIMIT,
        )

    resp = httpx.post(
        LINE_PUSH_URL,
        headers={"Authorization": f"Bearer {settings.digest_line_token}"},
        json={
            "to": settings.digest_line_user_id,
            "messages": [{"type": "text", "text": text}],
        },
        timeout=30,
    )
    resp.raise_for_status()
    logger.info("LINE notification sent (%d chars, %d articles)", len(text), total_articles)


PROVIDERS = {"slack": _send_slack, "line": _send_line}


def main() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )

    provider = settings.digest_provider
    if provider not in PROVIDERS:
        logger.error("Unknown digest_provider %r (expected: slack, line)", provider)
        sys.exit(1)

    if provider == "slack" and not settings.digest_webhook_url:
        logger.error("FEEDFORGE_DIGEST_WEBHOOK_URL is required for Slack provider")
        sys.exit(1)
    if provider == "line" and (not settings.digest_line_token or not settings.digest_line_user_id):
        logger.error("FEEDFORGE_DIGEST_LINE_TOKEN and FEEDFORGE_DIGEST_LINE_USER_ID are required for LINE provider")
        sys.exit(1)

    logger.info("Daily digest starting (provider=%s, lookback=%dh)", provider, settings.digest_lookback_hours)
    start = time.monotonic()

    db = SessionLocal()
    try:
        total_fetched = count_recent_articles(db)
        articles = get_recent_articles(db)
        unsummarized = total_fetched - len(articles)

        logger.info(
            "Digest pipeline: %d fetched, %d summarized, %d missing summaries",
            total_fetched, len(articles), unsummarized,
        )

        if not articles:
            logger.info("No articles with summaries in the last %d hours, skipping", settings.digest_lookback_hours)
            return

        text = format_digest(articles)
        PROVIDERS[provider](text, len(articles))

        elapsed = time.monotonic() - start
        logger.info("Digest complete: %d articles sent (%.1fs)", len(articles), elapsed)
    finally:
        db.close()


if __name__ == "__main__":
    main()
