"""Read secrets from CSI-mounted files, with env-var fallback for local dev.

The CSI driver mounts secret files synchronously when the pod starts, so reads
from `/mnt/secrets/...` are race-free (unlike env vars sourced from a synced
K8s Secret, whose creation is async and lags the pod's first start).

Helpers are called per use (not cached at import) so rotated CSI files are
picked up on subsequent reads — at the granularity of the caller (e.g. each
new SQLAlchemy pool connection re-reads DB credentials).
"""

import os
from pathlib import Path

POSTGRES_SECRETS_DIR = Path("/mnt/secrets/postgres")
NOTIFICATION_SECRETS_DIR = Path("/mnt/secrets/notification")


def read_secret(file_key: str, *, mount_dir: Path, env_var: str | None = None) -> str:
    """Return the secret value for `file_key`.

    Prefers `<mount_dir>/<file_key>` when the file exists; otherwise falls back
    to `os.environ[env_var]` for local-dev paths where no CSI mount is present.
    Returns "" when neither source has a value, matching the pre-existing
    pydantic-settings empty-string default that downstream guards already check.
    """
    file_path = mount_dir / file_key
    if file_path.is_file():
        return file_path.read_text().strip()
    if env_var:
        return os.environ.get(env_var, "")
    return ""


def get_db_credentials() -> tuple[str, str]:
    user = read_secret("POSTGRES_USER", mount_dir=POSTGRES_SECRETS_DIR, env_var="FEEDFORGE_DB_USER")
    password = read_secret("POSTGRES_PASSWORD", mount_dir=POSTGRES_SECRETS_DIR, env_var="FEEDFORGE_DB_PASSWORD")
    return user, password


def get_notification_secret(file_key: str, env_var: str) -> str:
    return read_secret(file_key, mount_dir=NOTIFICATION_SECRETS_DIR, env_var=env_var)
