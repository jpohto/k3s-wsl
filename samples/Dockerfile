FROM debian:bookworm AS nvidia-smi

ENTRYPOINT ["nvidia-smi"]

FROM debian:bookworm AS pytorch

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-pip python3-venv \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN python3 -m venv /opt/venv && . /opt/venv/bin/activate && \
    pip3 install --upgrade pip setuptools wheel && \
    pip3 install --no-cache-dir numpy torch --index-url https://download.pytorch.org/whl/cu130

ENV PATH="/opt/venv/bin:$PATH"
CMD ["python3", "-c", "import torch; print(torch.__version__); print(torch.cuda.is_available()); print(torch.cuda.get_device_name(0));"]
