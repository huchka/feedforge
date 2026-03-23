import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.article import Article
from app.models.feed import Feed
from app.schemas.article import ArticleCreate, ArticleResponse

router = APIRouter()


@router.get("/articles", response_model=list[ArticleResponse])
def list_articles(
    feed_id: uuid.UUID | None = Query(None),
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db),
) -> list[Article]:
    query = db.query(Article).order_by(Article.created_at.desc())
    if feed_id:
        query = query.filter(Article.feed_id == feed_id)
    return list(query.offset(offset).limit(limit).all())


@router.get("/articles/{article_id}", response_model=ArticleResponse)
def get_article(article_id: uuid.UUID, db: Session = Depends(get_db)) -> Article:
    article = db.get(Article, article_id)
    if not article:
        raise HTTPException(status_code=404, detail="Article not found")
    return article


@router.post(
    "/feeds/{feed_id}/articles",
    response_model=ArticleResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_article(
    feed_id: uuid.UUID, body: ArticleCreate, db: Session = Depends(get_db)
) -> Article:
    feed = db.get(Feed, feed_id)
    if not feed:
        raise HTTPException(status_code=404, detail="Feed not found")
    article = Article(
        feed_id=feed_id,
        url=body.url,
        title=body.title,
        author=body.author,
        content=body.content,
        published_at=body.published_at,
    )
    db.add(article)
    db.commit()
    db.refresh(article)
    return article


@router.get("/feeds/{feed_id}/articles", response_model=list[ArticleResponse])
def list_feed_articles(
    feed_id: uuid.UUID,
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db),
) -> list[Article]:
    feed = db.get(Feed, feed_id)
    if not feed:
        raise HTTPException(status_code=404, detail="Feed not found")
    return list(
        db.query(Article)
        .filter(Article.feed_id == feed_id)
        .order_by(Article.created_at.desc())
        .offset(offset)
        .limit(limit)
        .all()
    )
