from collections.abc import Generator

import psycopg
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

from app.config import settings
from app.secrets import get_db_credentials


def _connect() -> psycopg.Connection:
    user, password = get_db_credentials()
    return psycopg.connect(
        host=settings.db_host,
        port=settings.db_port,
        dbname=settings.db_name,
        user=user,
        password=password,
    )


# `creator=` re-runs `_connect` for every new pool connection, so credentials
# rotated in the CSI mount are picked up without an engine restart.
engine = create_engine("postgresql+psycopg://", creator=_connect)
SessionLocal = sessionmaker(bind=engine)


def get_db() -> Generator[Session, None, None]:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
