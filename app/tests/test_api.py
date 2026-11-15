def test_health(client):
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json()["status"] == "ok"


def test_ready(client):
    assert client.get("/ready").status_code == 200


def test_task_crud(client):
    created = client.post("/tasks", json={"title": "write terraform"})
    assert created.status_code == 201
    task_id = created.json()["id"]

    assert client.get(f"/tasks/{task_id}").json()["title"] == "write terraform"

    updated = client.put(f"/tasks/{task_id}", json={"title": "write terraform", "done": True})
    assert updated.json()["done"] is True

    assert len(client.get("/tasks").json()) == 1
    assert client.delete(f"/tasks/{task_id}").status_code == 204
    assert client.get(f"/tasks/{task_id}").status_code == 404


def test_rejects_empty_title(client):
    assert client.post("/tasks", json={"title": ""}).status_code == 422


def test_metrics_exposed(client):
    client.get("/health")
    assert "http_requests_total" in client.get("/metrics").text
