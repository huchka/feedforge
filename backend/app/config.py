from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    db_host: str = "localhost"
    db_port: int = 5432
    db_name: str = "feedforge"
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

    model_config = {"env_prefix": "FEEDFORGE_"}


settings = Settings()
