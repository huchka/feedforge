import uuid
from datetime import datetime

from pydantic import BaseModel, HttpUrl


class FeedCreate(BaseModel):
    url: HttpUrl
    title: str | None = None
    fetch_interval_minutes: int = 60


class FeedUpdate(BaseModel):
    title: str | None = None
    site_url: str | None = None
    fetch_interval_minutes: int | None = None
    is_active: bool | None = None


class FeedResponse(BaseModel):
    id: uuid.UUID
    url: str
    title: str | None
    site_url: str | None
    feed_type: str | None
    fetch_interval_minutes: int
    last_fetched_at: datetime | None
    is_active: bool
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}
