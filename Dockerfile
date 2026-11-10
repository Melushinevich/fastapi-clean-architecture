#Сборка зависимостей
FROM python:3.10.13-bookworm AS builder

ENV PIP_NO_CACHE_DIR=1\
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PYTHONDONTWRITEBYTECODE=1

WORKDIR /build

COPY requirements.txt .

RUN apt-get update && \
    apt-get install -y --no-install-recommends libpq-dev build-essential && \
    pip install --prefix=/install -r requirements.txt && \
    apt-get purge -y --auto-remove libpq-dev build-essential && \
    rm -rf /var/lib/apt/lists/*


#production
FROM python:3.10.13-slim-bookworm AS production

RUN groupadd --gid 1000 appgroup && \
    useradd --uid 1000 --gid appgroup --shell /bin/bash --create-home appuser

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONFAULTHADLER=1 \
    PATH="/install/bin:$PATH" \
    PYTHONPATH="/install/lib/python3.10/site-packages"

WORKDIR /app

COPY --from=builder --chown=appuser:appgroup /install /install

COPY --chown=appuser:appgroup . .

RUN apt-get update && \
    apt-get install --no-install-recommends -y tini postgresql-client && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/docs')" || exit 1

USER appuser

EXPOSE 8000

ENTRYPOINT ["/usr/bin/tini", "--"]

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
