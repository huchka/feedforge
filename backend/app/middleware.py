import re
import time

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response

from app.metrics import REQUEST_COUNT, REQUEST_LATENCY, REQUESTS_IN_PROGRESS

# Normalize numeric path segments to prevent cardinality explosion
_ID_PATTERN = re.compile(r"/\d+")


def _normalize_path(path: str) -> str:
    return _ID_PATTERN.sub("/{id}", path)


class PrometheusMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next) -> Response:  # noqa: ANN001
        if request.url.path == "/metrics":
            return await call_next(request)

        method = request.method
        REQUESTS_IN_PROGRESS.labels(method=method).inc()
        start = time.perf_counter()

        try:
            response = await call_next(request)
        except Exception:
            REQUEST_COUNT.labels(
                method=method,
                endpoint=_normalize_path(request.url.path),
                status_code="500",
            ).inc()
            raise
        finally:
            duration = time.perf_counter() - start
            REQUESTS_IN_PROGRESS.labels(method=method).dec()

        endpoint = _normalize_path(request.url.path)
        REQUEST_COUNT.labels(
            method=method, endpoint=endpoint, status_code=str(response.status_code)
        ).inc()
        REQUEST_LATENCY.labels(method=method, endpoint=endpoint).observe(duration)

        return response
