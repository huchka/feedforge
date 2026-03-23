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
        return f"postgresql+psycopg://{self.db_user}:{self.db_password}@{self.db_host}:{self.db_port}/{self.db_name}"


settings = Settings()
