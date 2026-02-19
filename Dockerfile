# FreeLang Streaming Arena - Docker Image
# Build: docker build -t freelang-streaming-arena:1.0.0 .
# Run:   docker run --rm -m 4g freelang-streaming-arena:1.0.0 --insights=10000000

FROM ubuntu:22.04

LABEL maintainer="kim@dclub.kr"
LABEL description="FreeLang v4 Streaming Analytics Engine for 100M+ insights"
LABEL version="1.0.0"

# Install dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    git \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install FreeLang v4
RUN mkdir -p /opt/freelang && \
    cd /opt/freelang && \
    curl -L https://gogs.dclub.kr/kim/v2-freelang-ai/raw/master/freelang-v4.tar.gz \
    -o freelang-v4.tar.gz && \
    tar xzf freelang-v4.tar.gz && \
    chmod +x bin/freelang

# Add FreeLang to PATH
ENV PATH="/opt/freelang/bin:${PATH}"

# Create app directory
WORKDIR /app

# Copy source code
COPY src /app/src
COPY tests /app/tests
COPY package.json /app/
COPY README.md /app/
COPY .gitignore /app/

# Build
RUN freelang build src/main.free -o bin/main

# Runtime configuration
ENV FREELANG_INSIGHTS=1000000
ENV FREELANG_LOG_LEVEL=INFO
ENV FREELANG_BATCH_SIZE=100000

# Expose for monitoring (if needed)
EXPOSE 9090

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD freelang check || exit 1

# Run application
ENTRYPOINT ["./bin/main"]
CMD ["--insights=1000000", "--log-level=INFO"]
