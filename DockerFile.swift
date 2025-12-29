# For Swift Development
FROM docker.io/swift:latest

WORKDIR /workdir

RUN apt-get update && \
    apt-get -y install npm file curl ripgrep jq python-is-python3
RUN npm i -g @openai/codex 

COPY config.toml /root/.codex/

# Configure git
RUN git config --global user.email "codex@localhost" && \
    git config --global user.name "Codex CLI" && \
    git config --global init.defaultBranch "main"

CMD codex --dangerously-bypass-approvals-and-sandbox
