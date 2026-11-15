import os

from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, sessionmaker

# Local default is SQLite. In Docker/Kubernetes this is set to Postgres:
#   postgresql+psycopg://user:password@host:5432/dbname
DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./local.db")

# SQLite: allow use across FastAPI's threads. Postgres: fail fast instead of hanging when the
# database is unreachable, so startup retries (see main.init_db) actually get to retry.
_connect_args = (
    {"check_same_thread": False} if DATABASE_URL.startswith("sqlite") else {"connect_timeout": 5}
)
engine = create_engine(DATABASE_URL, pool_pre_ping=True, connect_args=_connect_args)
SessionLocal = sessionmaker(bind=engine, expire_on_commit=False)


class Base(DeclarativeBase):
    pass


def get_session():
    with SessionLocal() as session:
        yield session
