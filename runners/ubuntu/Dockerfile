# ==============================================================================
# Custom GitHub Actions Self-Hosted Runner — Ubuntu 22.04
# Pre-installed: .NET 8, Python 3.12, Node 20, Azure CLI, Docker CLI
# Security: non-root runner user
# ==============================================================================
FROM ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# ── OS packages & dependencies ───────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    jq \
    unzip \
    zip \
    wget \
    apt-transport-https \
    software-properties-common \
    gnupg \
    lsb-release \
    sudo \
    build-essential \
    libicu-dev \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# ── .NET 8 SDK ───────────────────────────────────────────────────
RUN curl -sSL https://dot.net/v1/dotnet-install.sh | bash /dev/stdin \
    --channel 8.0 --install-dir /usr/share/dotnet
ENV DOTNET_ROOT=/usr/share/dotnet
ENV PATH="${DOTNET_ROOT}:${PATH}"

# ── Python 3.12 ──────────────────────────────────────────────────
RUN add-apt-repository ppa:deadsnakes/ppa -y && \
    apt-get update && apt-get install -y --no-install-recommends \
    python3.12 python3.12-venv python3.12-dev python3-pip && \
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1 && \
    rm -rf /var/lib/apt/lists/*

# ── Node.js 20 LTS ──────────────────────────────────────────────
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    rm -rf /var/lib/apt/lists/*

# ── Azure CLI ────────────────────────────────────────────────────
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash && \
    rm -rf /var/lib/apt/lists/*

# ── Docker CLI (for container builds inside runner) ──────────────
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
    > /etc/apt/sources.list.d/docker.list && \
    apt-get update && apt-get install -y --no-install-recommends docker-ce-cli && \
    rm -rf /var/lib/apt/lists/*

# ── GitHub Actions Runner ────────────────────────────────────────
ARG RUNNER_VERSION=2.321.0
ARG RUNNER_ARCH=x64

RUN mkdir -p /home/runner && \
    curl -sSL "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz" \
    | tar -xz -C /home/runner

# ── Security: non-root user ─────────────────────────────────────
RUN useradd -m -d /home/runner -s /bin/bash runner && \
    chown -R runner:runner /home/runner && \
    echo "runner ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

WORKDIR /home/runner
USER runner

# ── Entrypoint: configure and run ────────────────────────────────
COPY entrypoint.sh /home/runner/entrypoint.sh
USER root
RUN chmod +x /home/runner/entrypoint.sh
USER runner

ENTRYPOINT ["/home/runner/entrypoint.sh"]
