.PHONY: help compose-up compose-down cluster-up cluster-down deploy-local dev-local use-cloudsql

CLOUD_SQL_INSTANCE ?= project-76da2d1f-231c-4c94-ae9:us-central1:feedforge-postgres

help:
	@echo "Tier 1 — host-direct dev (deps via docker-compose):"
	@echo "  make compose-up        Start Postgres + Redis on localhost:5432 / :6379"
	@echo "  make compose-down      Stop them"
	@echo ""
	@echo "Tier 2 — kind cluster:"
	@echo "  make cluster-up        Create kind cluster, install Calico + CNPG"
	@echo "  make cluster-down      Delete the cluster"
	@echo "  make deploy-local      skaffold run -p local (one-shot deploy)"
	@echo "  make dev-local         skaffold dev -p local (watch + redeploy)"
	@echo ""
	@echo "Hybrid — Tier 1 against real Cloud SQL:"
	@echo "  make use-cloudsql      Run Cloud SQL Auth Proxy on localhost:5433"

compose-up:
	docker compose up -d

compose-down:
	docker compose down

cluster-up:
	./scripts/local-cluster-up.sh

cluster-down:
	./scripts/local-cluster-down.sh

deploy-local:
	skaffold run -p local

dev-local:
	skaffold dev -p local

use-cloudsql:
	@echo "==> Starting Cloud SQL Auth Proxy on localhost:5433"
	@echo "    (Ctrl-C to stop. Requires 'gcloud auth application-default login'.)"
	@echo ""
	@echo "    Set in .env.local while this runs:"
	@echo "      FEEDFORGE_DB_HOST=localhost"
	@echo "      FEEDFORGE_DB_PORT=5433"
	@echo "      FEEDFORGE_DB_USER=<from Secret Manager>"
	@echo "      FEEDFORGE_DB_PASSWORD=<from Secret Manager>"
	@echo ""
	cloud-sql-proxy --port 5433 $(CLOUD_SQL_INSTANCE)
