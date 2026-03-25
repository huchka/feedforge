import uuid
from datetime import datetime

from pydantic import BaseModel


class ArticleCreate(BaseModel):
    url: str
    title: str
    author: str | None = None
    content: str | None = None
    published_at: datetime | None = None


class ArticleUpdate(BaseModel):
    is_read: bool | None = None
    is_favorite: bool | None = None


class ArticleResponse(BaseModel):
    id: uuid.UUID
    feed_id: uuid.UUID
    url: str
    title: str
    author: str | None
    content: str | None
    summary: str | None
    published_at: datetime | None
    fetched_at: datetime | None
    is_read: bool
    is_favorite: bool
    created_at: datetime

    model_config = {"from_attributes": True}
