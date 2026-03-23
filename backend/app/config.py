from urllib.parse import quote_plus

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    db_host: str = "localhost"
    db_port: int = 5432
    db_name: str = "feedforge"
    db_user: str = "feedforge"
    db_password: str = "feedforge"
    debug: bool = False

    model_config = {"env_prefix": "FEEDFORGE_"}

    @property
    def database_url(self) -> str:
        user = quote_plus(self.db_user)
        password = quote_plus(self.db_password)
        return f"postgresql+psycopg://{user}:{password}@{self.db_host}:{self.db_port}/{self.db_name}"


settings = Settings()
