from fastapi import APIRouter
from fastapi.responses import Response
from prometheus_client import CONTENT_TYPE_LATEST, generate_latest

from app.metrics import collect_business_metrics

router = APIRouter()


@router.get("/metrics")
def metrics() -> Response:
    collect_business_metrics()
    return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)
