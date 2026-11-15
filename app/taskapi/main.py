import logging
import os
import time
from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, HTTPException, Response, status
from prometheus_fastapi_instrumentator import Instrumentator
from pydantic import BaseModel, Field
from sqlalchemy import String, select, text
from sqlalchemy.exc import OperationalError, SQLAlchemyError
from sqlalchemy.orm import Mapped, Session, mapped_column

from .db import Base, engine, get_session

APP_VERSION = os.getenv("APP_VERSION", "dev")
log = logging.getLogger("taskapi")


class Task(Base):
    __tablename__ = "tasks"

    id: Mapped[int] = mapped_column(primary_key=True)
    title: Mapped[str] = mapped_column(String(200))
    done: Mapped[bool] = mapped_column(default=False)


class TaskIn(BaseModel):
    title: str = Field(min_length=1, max_length=200)
    done: bool = False


class TaskOut(TaskIn):
    id: int

    model_config = {"from_attributes": True}


SCHEMA_LOCK_ID = 727274  # arbitrary app-wide key for pg_advisory_xact_lock


def init_db(retries: int = 30, delay_seconds: float = 2.0) -> None:
    """Create tables once, safely, even when several replicas start at the same time.

    - Retries while the database is still starting (e.g. Postgres pod not ready yet).
    - On Postgres, takes an advisory lock so only one replica runs CREATE TABLE at a time;
      without it, two pods racing on an empty database crash with a duplicate-key error.
    """
    for attempt in range(1, retries + 1):
        try:
            with engine.begin() as conn:
                if conn.dialect.name == "postgresql":
                    conn.execute(text("SELECT pg_advisory_xact_lock(:id)"), {"id": SCHEMA_LOCK_ID})
                Base.metadata.create_all(conn)
            return
        except OperationalError:
            if attempt == retries:
                raise
            log.warning("database not ready (attempt %d/%d), retrying", attempt, retries)
            time.sleep(delay_seconds)


@asynccontextmanager
async def lifespan(_app: FastAPI):
    # TODO(stage 4): replace with Alembic migrations run as a Kubernetes Job
    init_db()
    yield


app = FastAPI(title="Task API", version=APP_VERSION, lifespan=lifespan)

# Exposes /metrics for Prometheus (stage 5)
Instrumentator().instrument(app).expose(app, include_in_schema=False)


@app.get("/health", tags=["ops"])
def health():
    """Liveness probe: the process is up."""
    return {"status": "ok", "version": APP_VERSION}


@app.get("/ready", tags=["ops"])
def ready(session: Session = Depends(get_session)):
    """Readiness probe: the database is reachable."""
    try:
        session.execute(text("SELECT 1"))
    except SQLAlchemyError as exc:
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, "database unavailable") from exc
    return {"status": "ready"}


@app.get("/tasks", response_model=list[TaskOut], tags=["tasks"])
def list_tasks(session: Session = Depends(get_session)):
    return session.scalars(select(Task).order_by(Task.id)).all()


@app.post("/tasks", response_model=TaskOut, status_code=status.HTTP_201_CREATED, tags=["tasks"])
def create_task(body: TaskIn, session: Session = Depends(get_session)):
    task = Task(**body.model_dump())
    session.add(task)
    session.commit()
    return task


def _get_or_404(session: Session, task_id: int) -> Task:
    task = session.get(Task, task_id)
    if task is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "task not found")
    return task


@app.get("/tasks/{task_id}", response_model=TaskOut, tags=["tasks"])
def get_task(task_id: int, session: Session = Depends(get_session)):
    return _get_or_404(session, task_id)


@app.put("/tasks/{task_id}", response_model=TaskOut, tags=["tasks"])
def update_task(task_id: int, body: TaskIn, session: Session = Depends(get_session)):
    task = _get_or_404(session, task_id)
    task.title, task.done = body.title, body.done
    session.commit()
    return task


@app.delete("/tasks/{task_id}", status_code=status.HTTP_204_NO_CONTENT, tags=["tasks"])
def delete_task(task_id: int, session: Session = Depends(get_session)):
    session.delete(_get_or_404(session, task_id))
    session.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
