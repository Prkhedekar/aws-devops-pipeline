import pytest
from sqlalchemy.exc import OperationalError

from taskapi import main


def test_init_db_is_idempotent(monkeypatch, tmp_path):
    from sqlalchemy import create_engine, inspect

    engine = create_engine(f"sqlite:///{tmp_path / 'db.sqlite'}")
    monkeypatch.setattr(main, "engine", engine)

    main.init_db()
    main.init_db()  # second run (e.g. another replica) must not fail

    assert "tasks" in inspect(engine).get_table_names()


def test_init_db_retries_until_database_is_ready(monkeypatch):
    calls = {"n": 0}

    class FlakyEngine:
        def begin(self):
            calls["n"] += 1
            raise OperationalError("SELECT 1", {}, Exception("connection refused"))

    monkeypatch.setattr(main, "engine", FlakyEngine())
    with pytest.raises(OperationalError):
        main.init_db(retries=3, delay_seconds=0)
    assert calls["n"] == 3
