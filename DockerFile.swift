# For Swift Development
FROM docker.io/swift:latest

WORKDIR /workdir

RUN apt-get update
RUN apt-get -y install npm socat file curl
RUN npm i -g @openai/codex 

COPY config.toml /root/.codex/

# Configure git
RUN git config --global user.email "codex@localhost"
RUN git config --global user.name "Codex CLI"
RUN git config --global init.defaultBranch main

CMD codex --dangerously-bypass-approvals-and-sandbox --cd /workdir
