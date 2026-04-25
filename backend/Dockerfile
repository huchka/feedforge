FROM python:3.12.8-slim AS builder

ARG INSTALL_DEV=false

COPY --from=ghcr.io/astral-sh/uv:0.6 /uv /usr/local/bin/uv

WORKDIR /app

COPY pyproject.toml uv.lock ./
RUN if [ "$INSTALL_DEV" = "true" ]; then \
      uv sync --frozen --no-install-project; \
    else \
      uv sync --frozen --no-dev --no-install-project; \
    fi

COPY . .
RUN if [ "$INSTALL_DEV" = "true" ]; then \
      uv sync --frozen; \
    else \
      uv sync --frozen --no-dev; \
    fi


FROM python:3.12.8-slim AS runtime

RUN groupadd -r feedforge && useradd -r -g feedforge -d /app -s /sbin/nologin feedforge

WORKDIR /app

COPY --from=builder /app/.venv /app/.venv
COPY --from=builder /app/app ./app
COPY --from=builder /app/alembic ./alembic
COPY --from=builder /app/alembic.ini ./

ENV PATH="/app/.venv/bin:$PATH"

USER feedforge

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
