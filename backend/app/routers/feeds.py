import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.feed import Feed
from app.schemas.feed import FeedCreate, FeedResponse, FeedUpdate

router = APIRouter()


@router.post("/feeds", response_model=FeedResponse, status_code=status.HTTP_201_CREATED)
def create_feed(body: FeedCreate, db: Session = Depends(get_db)) -> Feed:
    feed = Feed(
        url=str(body.url),
        title=body.title,
        fetch_interval_minutes=body.fetch_interval_minutes,
    )
    db.add(feed)
    db.commit()
    db.refresh(feed)
    return feed


@router.get("/feeds", response_model=list[FeedResponse])
def list_feeds(db: Session = Depends(get_db)) -> list[Feed]:
    return list(db.query(Feed).order_by(Feed.created_at.desc()).all())


@router.get("/feeds/{feed_id}", response_model=FeedResponse)
def get_feed(feed_id: uuid.UUID, db: Session = Depends(get_db)) -> Feed:
    feed = db.get(Feed, feed_id)
    if not feed:
        raise HTTPException(status_code=404, detail="Feed not found")
    return feed


@router.patch("/feeds/{feed_id}", response_model=FeedResponse)
def update_feed(
    feed_id: uuid.UUID, body: FeedUpdate, db: Session = Depends(get_db)
) -> Feed:
    feed = db.get(Feed, feed_id)
    if not feed:
        raise HTTPException(status_code=404, detail="Feed not found")
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(feed, field, value)
    db.commit()
    db.refresh(feed)
    return feed


@router.delete("/feeds/{feed_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_feed(feed_id: uuid.UUID, db: Session = Depends(get_db)) -> None:
    feed = db.get(Feed, feed_id)
    if not feed:
        raise HTTPException(status_code=404, detail="Feed not found")
    db.delete(feed)
    db.commit()
