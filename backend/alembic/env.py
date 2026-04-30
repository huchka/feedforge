from urllib.parse import quote_plus

import psycopg
from alembic import context
from sqlalchemy import create_engine, pool

from app.config import settings
from app.models import Base
from app.secrets import get_db_credentials

target_metadata = Base.metadata


def _connect() -> psycopg.Connection:
    user, password = get_db_credentials()
    return psycopg.connect(
        host=settings.db_host,
        port=settings.db_port,
        dbname=settings.db_name,
        user=user,
        password=password,
    )


def _offline_url() -> str:
    user, password = get_db_credentials()
    return (
        f"postgresql+psycopg://{quote_plus(user)}:{quote_plus(password)}"
        f"@{settings.db_host}:{settings.db_port}/{settings.db_name}"
    )


def run_migrations_offline() -> None:
    context.configure(url=_offline_url(), target_metadata=target_metadata, literal_binds=True)
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    connectable = create_engine("postgresql+psycopg://", creator=_connect, poolclass=pool.NullPool)
    with connectable.connect() as connection:
        context.configure(connection=connection, target_metadata=target_metadata)
        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
