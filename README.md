# Local Codex using Ollama & Apple Container

This is repository is combining multiple Open Source tools to run an agentic AI safely and privately on a Mac.

It is running OpenAIs [Codex CLI](https://github.com/openai/codex) within Apples Containerization Framework (which is part of macOS 15 and 26), connecting to a locally running Ollama instance.

All those tools are available as Open Source on GitHub:

- [`container`](https://github.com/apple/container/)
- [Codex CLI](https://github.com/openai/codex)
- [Ollama](https://github.com/ollama/ollama)

## Preliminary setup

I suppose you do not want to install everything from source (which would be doable). So therefore here are links to install the official releases of Ollama and Apples container tool:

1. Container tool: https://github.com/apple/container/releases
2. Ollama: https://ollama.com/download

## Network configuration

By default, Ollama is only listening on localhost connections, i.e. on http://localhost:11434 or http://127.0.0.1:11434. To be able to connect from a container (through a virtual network) to the Ollama service running on localhost, we have two options:

### Option 1: Expose service on LAN

Expose the Ollama service to **ALL** network connections, by enabling the setting "Expose Ollama to the network" in the Ollama GUI.
The **problem** with this approach: when connected to a "untrusted" public network, the Ollama service is visible to other computers and risks to be abused/attacked.  
You should consider stopping the service in these cases!

### Option 2: Additional service on virtual network

Instead of using the GUI setting within Ollama you can launch the Ollama service listening only on the virtual network interface using the following command:

    OLLAMA_HOST=192.168.64.1 ollama serve

The consequence is, that you run two Ollama services on your computer: the first throught the Ollama GUI App and the second through your CLI.

### Option 3.1: Proxy service connecting virtual to localhost

In this option we are running a tool which listens on the virtual network interface 192.168.64.1 and forwards to the service running on localhost.

This can be done using `socat` (a tool to install using `brew install socat`)

    socat TCP-LISTEN:11434,fork,bind=192.168.64.1 TCP:127.0.0.1:11434

This command only works when a container is already running! (see next sections).  
Otherwise you will get the following error:

    socat[12345] E bind(5, {LEN=16 AF=2 192.168.64.1:11434}, 16): Can't assign requested address

### Option 3.2: OllamaProxy

Alternatively if you are interested in also reading what the container is talking with Ollama, you can use my `OllamaProxy`, available as a Swift Pacakage at https://github.com/pd95/OllamaProxy.  

This tool should be run in a separate Terminal window, as it will log all the "chat" running proxied to/from Ollama.

    swift build
    HOST=192.168.64.1 PORT=11434 swift run

## Build a codex container

To build the codex container image for later use I have written three `DockerFile`s which are installing `codex`, `git` and other basic tools (`bash`, `npm`, `file`, `curl`):

- `DockerFile` for a plain Alpine Linux (~320 MB)
- `DockerFile.python` for a Alpine based Python installation (~330 MB)
- `DockerFile.swift` for an Ubuntu based Swift installation (~1.68 GB)

The build process is using `npm` to install the latest `openai/codex` package, and configures `git` to use "Codex CLI" and `codex@localhost` as its identifier when interacting with git and to use `main` as the default branch when initializing a new repository.

Further the build process is going to copy the `config.toml` file into the container at `~/.codex/` so that codex will properly connect to the locally running Ollama instance on 192.168.64.1.

Use the following `container` commands to build the codex containers from the corresponding `DockerFile` source:

    container build -t codex -f DockerFile

    container build -t codex-python -f DockerFile.python

    container build -t codex-swift -f DockerFile.swift

## Run a codex container in the current directory

The following command runs a "throwaway" `codex` container with the current directory as 'workdir'

    container run --rm -it --mount type=bind,src="$(pwd)",dst=/workdir codex

You can name the container using the '--name' argument:

    container run --rm -it --name "my-codex" --mount type=bind,src="$(pwd)",dst=/workdir codex

To start a `bash` within the same (running!) container, you can use

    container exec -it "my-codex" bash

If you want to keep your session/chat history over multiple runs, do not remove the container after termination (=omit `--rm` argument and make sure you give it a unique name!):

    container run -it --name "codex-`basename $PWD`" --mount type=bind,src="$(pwd)",dst=/workdir codex

Later you can start the container again:

    container start -i "codex-`basename $PWD`"

To remove the old/unused container later:

    container rm "codex-`basename $PWD`"

To check what containers (even stopped ones) are lingering around use:

    container ls -a

If you want to run more CPU and memory hungry builds within the codex container, you can specify CPU and memory when starting:

    container run -it -c 6 -m 8G --name "codex-`basename $PWD`" --mount type=bind,src="$(pwd)",dst=/workdir codex
