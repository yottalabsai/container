FROM yottalabsai/pytorch:2.8.0-py3.11-cuda12.8.1-cudnn-devel-ubuntu22.04-2025081902

ENV NCCL_DEBUG=TRACE

WORKDIR /verify-nccl

# Install additional packages
# hadolint ignore=DL3008
RUN apt-get update && apt-get install -y --no-install-recommends \
    nano \
    pciutils \
    && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/NVIDIA/cuda-samples.git && \
    make -C cuda-samples/Samples/0_Introduction/simpleP2P

COPY check_nccl.sh .
RUN chmod +x check_nccl.sh

# Start Container
CMD ["tail", "-f", "/dev/null"]
