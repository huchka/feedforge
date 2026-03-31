"""AI summarizer worker — consumes article IDs from Redis, summarizes via Gemini, writes to DB."""

import logging
import signal
import time
import uuid

import redis
from google import genai
from sqlalchemy import select

from app.config import settings
from app.database import SessionLocal
from app.models.article import Article

logger = logging.getLogger(__name__)

QUEUE_KEY = "feedforge:articles:pending"
BRPOP_TIMEOUT = 30

SYSTEM_PROMPT = (
    "You are a concise article summarizer. "
    "Given an article title and content, produce a 1-2 sentence summary "
    "that captures the key point. Be factual and neutral. "
    "Aim for around {max_chars} characters. "
    "Always write complete sentences."
)

MAX_CONTENT_CHARS = 4000

_shutdown = False


def _handle_signal(signum, frame):
    global _shutdown
    logger.info("Received signal %s, shutting down gracefully", signum)
    _shutdown = True


def get_redis_client() -> redis.Redis:
    return redis.Redis(
        host=settings.redis_host,
        port=settings.redis_port,
        db=settings.redis_db,
        decode_responses=True,
    )


def get_llm_client() -> genai.Client:
    """Create a Gemini client via Vertex AI."""
    if settings.llm_provider != "gemini":
        raise ValueError(f"Unsupported LLM provider: {settings.llm_provider}")

    return genai.Client(
        vertexai=True,
        project=settings.gcp_project_id,
        location=settings.gcp_location,
    )


def summarize_article(article: Article, client: genai.Client) -> str | None:
    """Send article content to Gemini and return the summary."""
    content = article.content or ""
    if len(content) > MAX_CONTENT_CHARS:
        content = content[:MAX_CONTENT_CHARS] + "..."

    max_chars = settings.summary_max_chars
    user_message = f"Title: {article.title}\n\nContent:\n{content}"
    system_prompt = SYSTEM_PROMPT.format(max_chars=max_chars)

    try:
        response = client.models.generate_content(
            model=settings.llm_model,
            contents=user_message,
            config=genai.types.GenerateContentConfig(
                system_instruction=system_prompt,
                max_output_tokens=256,
                temperature=0.3,
                thinking_config=genai.types.ThinkingConfig(thinking_budget=0),
            ),
        )
        summary = response.text
        if len(summary) > max_chars:
            logger.warning(
                "Summary for article %s exceeded %d chars (%d), truncating",
                article.id, max_chars, len(summary),
            )
            last_period = summary.rfind(".", 0, max_chars)
            summary = summary[:last_period + 1] if last_period > 0 else summary[:max_chars]
        return summary
    except Exception:
        logger.exception("Gemini API error for article %s", article.id)
        return None


def backfill_unsummarized(db, redis_client: redis.Redis) -> int:
    """Push IDs of articles missing summaries to the Redis queue."""
    stmt = select(Article.id).where(Article.summary.is_(None))
    article_ids = list(db.scalars(stmt).all())

    if not article_ids:
        return 0

    for aid in article_ids:
        redis_client.lpush(QUEUE_KEY, str(aid))

    logger.info("Backfilled %d unsummarized articles to queue", len(article_ids))
    return len(article_ids)


def process_one(article_id_str: str, db, client: genai.Client) -> bool:
    """Fetch article, summarize, and write back. Returns True on success."""
    try:
        article_id = uuid.UUID(article_id_str)
    except ValueError:
        logger.warning("Invalid article ID in queue: %s", article_id_str)
        return False

    article = db.get(Article, article_id)
    if article is None:
        logger.debug("Article %s not found (deleted?), skipping", article_id)
        return False

    if article.summary is not None:
        logger.debug("Article %s already summarized, skipping", article_id)
        return True

    summary = summarize_article(article, client)
    if summary is None:
        return False

    article.summary = summary
    db.commit()
    logger.info("Summarized article %s: %s", article.id, article.title[:80])
    return True


def main() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )

    signal.signal(signal.SIGTERM, _handle_signal)
    signal.signal(signal.SIGINT, _handle_signal)

    logger.info("Summarizer worker starting (provider=%s, model=%s)", settings.llm_provider, settings.llm_model)

    redis_client = get_redis_client()
    redis_client.ping()
    logger.info("Connected to Redis at %s:%s", settings.redis_host, settings.redis_port)

    client = get_llm_client()
    logger.info("Vertex AI client ready (project=%s, location=%s)", settings.gcp_project_id, settings.gcp_location)

    db = SessionLocal()
    try:
        backfill_unsummarized(db, redis_client)

        processed = 0
        errors = 0
        start = time.monotonic()

        while not _shutdown:
            result = redis_client.brpop(QUEUE_KEY, timeout=BRPOP_TIMEOUT)
            if result is None:
                continue

            _, article_id_str = result
            try:
                if process_one(article_id_str, db, client):
                    processed += 1
                else:
                    errors += 1
            except Exception:
                logger.exception("Unexpected error processing article %s", article_id_str)
                db.rollback()
                errors += 1

        elapsed = time.monotonic() - start
        logger.info("Summarizer shutting down: %d processed, %d errors (%.1fs)", processed, errors, elapsed)
    finally:
        db.close()


if __name__ == "__main__":
    main()
