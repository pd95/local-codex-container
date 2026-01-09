# For Swift Development
FROM docker.io/swift:latest

WORKDIR /workdir

RUN apt-get update && \
    apt-get -y install npm file curl ripgrep jq python-is-python3 util-linux
RUN npm i -g @openai/codex 

RUN groupadd -r codex && useradd -r -g codex -m -d /home/codex -s /bin/bash codex && \
    mkdir -p /home/codex/.codex /workdir && \
    chown -R codex:codex /home/codex /workdir

COPY --chown=codex:codex config.toml /home/codex/.codex/

# Configure git
RUN su -s /bin/bash -c "git config --global user.email \"codex@localhost\" && \
    git config --global user.name \"Codex CLI\" && \
    git config --global init.defaultBranch \"main\"" codex

ENV HOME=/home/codex USER=codex
USER codex

ENTRYPOINT ["setpriv","--inh-caps=-all","--ambient-caps=-all","--bounding-set=-all","--no-new-privs","--"]
CMD ["codex","--dangerously-bypass-approvals-and-sandbox","--profile","gpt-oss"]
