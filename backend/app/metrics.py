from prometheus_client import Counter, Gauge, Histogram

REQUEST_COUNT = Counter(
    "feedforge_http_requests_total",
    "Total HTTP requests",
    ["method", "endpoint", "status_code"],
)

REQUEST_LATENCY = Histogram(
    "feedforge_http_request_duration_seconds",
    "HTTP request duration in seconds",
    ["method", "endpoint"],
)

REQUESTS_IN_PROGRESS = Gauge(
    "feedforge_http_requests_in_progress",
    "Number of HTTP requests currently being processed",
    ["method"],
)
