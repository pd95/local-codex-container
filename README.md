# Local Codex using Ollama & Apple Container

This is repository is combining multiple Open Source tools to run an agentic AI safely on a Mac.

It is running OpenAIs [Codex CLI](https://github.com/openai/codex) within Apples Containerization Framework (which is part of macOS 15 and 26), connecting to a locally running Ollama instance.

All those tools are available as Open Source on GitHub:

- [Ollama](https://github.com/ollama/ollama)
- [`container`](https://github.com/apple/container/)
- [Codex CLI](https://github.com/openai/codex)

## Preliminary setup

I suppose you do not want to install everything from source (which would be doable). So therefore here are links to install the official releases of Ollama and Apples container tool:

1. Ollama: https://ollama.com/download
2. Container tool: https://github.com/apple/container/releases

## Build a codex container

Building the codex container image for later use, I have written 3 descriptions:

- `DockerFile` for a plain Alpine Linux with `bash`, `npm`, `file`, `curl` and `git` installed
- `DockerFile.python` for a Alpine based python installation
- `DockerFile.swift` for the latest Swift release running in a Ubuntu environment.

Beside the basic tools described above, the build process is using `npm` to install the latest `openai/codex` package, and configures `git` to use "Codex CLI" and `codex@localhost` as its identifier when interacting with git and to use `main` as the default branch when initializing a new repository.

Further the build process is going to copy the `config.toml` file into the container in `~/.codex/` so that codex will properly connect to the locally running Ollama instance.

With following command `container` builds the codex container from the `DockerFile` source:

    container build -t codex

This variant is based on Alpine Linux

There are also specific containers for Python and Swift programming (using `DockerFile.python` and `DockerFile.swift`):

    container build -t codex-python -f DockerFile.python

    container build -t codex-swift -f DockerFile.swift

## Run a codex container in the current directory

The following command runs a "throwaway" `codex` container with the current directory as 'workdir'

    container run --rm -it --mount type=bind,src="$(pwd)",dst=/workdir codex

You can name the container using the '--name' argument:

    container run --rm -it --name "codex-`basename $PWD`" --mount type=bind,src="$(pwd)",dst=/workdir codex

To start a `bash` within the same (running!) container, you can use

    container exec -it "codex-`basename $PWD`" bash

If you want to keep your session/chat history over multiple runs, do not remove the container after termination (=omit `--rm` argument):

    container run -it --name "codex-`basename $PWD`" --mount type=bind,src="$(pwd)",dst=/workdir codex

Later you can start the container again:

    container start -i "codex-`basename $PWD`"

To check what containers (even stopped ones) are lingering around use:

    container ls -a

If you want to run more CPU and memory hungry builds within the codex container, you can specify CPU and memory when starting:

    container run -it -c 6 -m 8G --name "codex-`basename $PWD`" --mount type=bind,src="$(pwd)",dst=/workdir codex
