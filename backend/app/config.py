from urllib.parse import quote_plus

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    db_host: str = "localhost"
    db_port: int = 5432
    db_name: str = "feedforge"
    db_user: str = "feedforge"
    db_password: str = "feedforge"
    debug: bool = False

    redis_host: str = "localhost"
    redis_port: int = 6379
    redis_db: int = 0

    llm_provider: str = "gemini"
    llm_model: str = "gemini-2.5-flash"
    gcp_project_id: str = ""
    gcp_location: str = "us-central1"

    # Summarizer
    summary_max_chars: int = 200

    # Digest notification
    digest_lookback_hours: int = 24
    digest_provider: str = ""  # "slack" | "line" | "" (disabled)
    digest_webhook_url: str = ""  # Slack incoming webhook URL
    digest_line_token: str = ""  # LINE channel access token
    digest_line_user_id: str = ""  # LINE target user/group ID

    model_config = {"env_prefix": "FEEDFORGE_"}

    @property
    def database_url(self) -> str:
        user = quote_plus(self.db_user)
        password = quote_plus(self.db_password)
        return f"postgresql+psycopg://{user}:{password}@{self.db_host}:{self.db_port}/{self.db_name}"


settings = Settings()
