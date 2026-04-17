FROM node:22-bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
      git \
      ca-certificates \
      curl \
      openssh-client \
      tini \
      sudo \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g @anthropic-ai/claude-code@latest \
    && useradd -m -u 1000 -s /bin/bash claude \
    && mkdir -p /workspace /home/claude/.claude \
    && chown -R claude:claude /workspace /home/claude

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

USER claude
WORKDIR /workspace
ENV HOME=/home/claude

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
CMD ["claude", "remote-control", "--spawn", "same-dir", "--verbose"]
