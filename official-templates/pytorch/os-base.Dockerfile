\
# syntax=docker/dockerfile:1.7
# ===== OS Base Layer =====
# 说明：操作系统 + 通用工具 + ssh/nginx 所需依赖（语言无关）

ARG BASE_IMAGE="base"
FROM ${BASE_IMAGE}

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
      git acl wget curl ca-certificates bash \
      libgl1 software-properties-common \
      locales tzdata \
      openssh-server nginx sudo \
      tmux vim zsh zip unzip less procps net-tools htop \
      jq tree rsync netcat-openbsd \
      build-essential pkg-config \
    && echo "en_US.UTF-8 UTF-8" > /etc/locale.gen \
    && locale-gen \
    && mkdir -p /var/run/sshd \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
