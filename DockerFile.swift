# For Swift Development
FROM docker.io/swift:latest

WORKDIR /workdir

RUN apt-get update && \
    apt-get -y install npm file curl ripgrep jq python-is-python3 util-linux
RUN npm i -g @openai/codex 

RUN groupadd -r coder && useradd -r -g coder -m -d /home/coder -s /bin/bash coder && \
    mkdir -p /home/coder/.codex /workdir && \
    chown -R coder:coder /home/coder /workdir

COPY --chown=coder:coder config.toml /home/coder/.codex/

# Configure git
RUN su -s /bin/bash -c "git config --global user.email \"codex@localhost\" && \
    git config --global user.name \"Codex CLI\" && \
    git config --global init.defaultBranch \"main\"" coder

ENV HOME=/home/coder USER=coder
USER coder

ENTRYPOINT ["setpriv","--inh-caps=-all","--ambient-caps=-all","--bounding-set=-all","--no-new-privs","--"]
CMD ["codex","--profile","gpt-oss"]
