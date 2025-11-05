# Use multi-stage build for smaller final image
FROM python:3.13-slim as builder

# Install build dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Create virtual environment
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Copy and install Python dependencies
COPY ./requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r /tmp/requirements.txt

# Final stage - minimal runtime image
FROM python:3.13-slim

# Install only runtime dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    curl \
    wget \
    netcat-traditional \
    procps \
    dnsutils \
    lsof \
    net-tools \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get autoremove -y

# Copy virtual environment from builder stage
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Create non-root user for security
RUN groupadd -r appuser && useradd -r -g appuser appuser

WORKDIR /code

# Copy application code
COPY ./app /code/app

# Change ownership to non-root user
RUN chown -R appuser:appuser /code

# Set default concurrency (can be overridden via env var)
ENV WEB_CONCURRENCY=2

# Create startup script that handles environment variable expansion (as root before switching to appuser)
RUN echo '#!/bin/sh\nexec fastapi run app/main.py --port 8000 --host 0.0.0.0 --workers ${WEB_CONCURRENCY}' > /start.sh && \
    chmod +x /start.sh

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 8000

CMD ["/start.sh"]
