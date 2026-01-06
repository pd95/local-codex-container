# Local Codex on Mac

**Run Codex AI locally on macOS, powered by Ollama**

This repository is combining multiple Open Source tools to run an agentic AI safely and privately on a Mac.

It runs OpenAI's [Codex CLI](https://github.com/openai/codex) on your Mac using Apple's Containerization tool, connecting to the locally running Ollama instance.

All tools are available as Open Source on GitHub:

- `container`: [https://github.com/apple/container/](https://github.com/apple/container/)
- Codex CLI: [https://github.com/openai/codex](https://github.com/openai/codex)
- Ollama: [https://github.com/ollama/ollama](https://github.com/ollama/ollama)

## Prerequisites

You need a **Mac with Apple Silicon and at least 32 GB RAM**. The setup is currently only tested on macOS 26 but might also work on macOS 15 (possible restrictions apply to the `container` tool).

## Preliminary setup

I suppose you do not want to install everything from source (which would be doable). Therefore here are links to install the official releases of Ollama and Apple's `container` tool:

- `container` GitHub releases: [https://github.com/apple/container/releases](https://github.com/apple/container/releases)
- Ollama download page: [https://ollama.com/download](https://ollama.com/download)

After installing both tools, open Terminal app and run the following commands:

```bash
# Pull gpt-oss:20b model (requires 13 GB on disk!)
ollama pull gpt-oss:20b

# start the container API server (required for building container images)
container system start
```

## Use `codexctl` (recommended)

`codexctl` is the entry point for running Codex containers. It wraps the Apple `container` CLI, handles naming, and automates OpenAI device-auth when requested.

Quick start:

```bash
# Build images once
./codexctl build

# Run Codex for the current directory (persistent by default)
./codexctl run

# Throwaway session
./codexctl run --temp

# OpenAI mode (auto-auth if needed)
./codexctl run --openai

# Start a shell inside the container
./codexctl run --shell
```

Other useful commands:

```bash
./codexctl auth              # only run device-auth and store in Keychain
./codexctl exec --shell      # shell into running container
./codexctl ls                # list containers
./codexctl rm                # remove the default container for this directory
```

The rest of this README explains what `codexctl` does behind the scenes and how to run the underlying `container` commands directly.

## Behind the scenes

### Build codex container images

To build the codex container images for later use, I have written three `DockerFile`s which are installing `codex`, `git` and other basic tools (`bash`, `npm`, `file`, `curl`):

- `DockerFile` for a plain Alpine Linux (~320 MB)
- `DockerFile.python` for a Alpine based Python installation (~330 MB)
- `DockerFile.swift` for an Ubuntu based Swift installation (~1.68 GB)

The image build process is using `npm` to install the latest `openai/codex` package, and configures `git` to use "Codex CLI" and `codex@localhost` as the container users identifier when interacting with git and to use `main` as the default branch when initializing a new repository.

Further the build process is going to copy the `config.toml` file into the container at `~/.codex/` so that codex will properly connect to the locally running Ollama instance on the `default` networks host IP address 192.168.64.1.

Use the following `container` commands to build the codex containers `codex`, `codex-python` and `codex-swift` from the corresponding `DockerFile` source:

```bash
container build -t codex -f DockerFile
container build -t codex-python -f DockerFile.python
container build -t codex-swift -f DockerFile.swift
```

### Network configuration

By default, Ollama is only listening on localhost connections, i.e. on <http://localhost:11434> or <http://127.0.0.1:11434>. To be able to connect from a container (through a virtual network) to the Ollama service running on localhost, we have two options:

### Option 1: Expose Ollama service on network (**risky**) ⚠️

Expose the Ollama service to **ALL** network connections, by activating the setting "Expose Ollama to the network" in the Ollama GUI.  
The **problem** of this approach: when connected to a "untrusted" public network, the Ollama service is visible to other computers and risks to be abused or attacked.  
You should consider stopping the service on such networks!

### Option 2: Additional service on virtual network

Instead of using the GUI setting within Ollama you can launch a second Ollama service listening only on the virtual network interface using the following command:

    OLLAMA_HOST=192.168.64.1 ollama serve

⚠️ Be aware: This command only works when a container is already running! (see next chapter).  
Otherwise you will get the following error:

    Error: listen tcp 192.168.64.1:11434: bind: can't assign requested address

### Option 3: Proxy service connecting virtual network to localhost

The following sub‑options provide ways to forward traffic from the container's network interface to the Ollama service running on the host.

#### Option 3.1: socat proxy

In this option we are running a tool which listens on the virtual network interface `192.168.64.1` and forwards to the service running on localhost.

This can be done using `socat` (install with `brew install socat`):

```bash
socat TCP-LISTEN:11434,fork,bind=192.168.64.1 TCP:127.0.0.1:11434
```

⚠️ This command only works when a container is already running! (see next chapter). Otherwise you will get the following error:

```bash
socat[12345] E bind(5, {LEN=16 AF=2 192.168.64.1:11434}, 16): Can't assign requested address
```

#### Option 3.2: OllamaProxy

Alternatively if you are interested in also reading what the container is talking with Ollama, you can use my [OllamaProxy Swift app](https://github.com/pd95/OllamaProxy).

This tool should be run in a separate Terminal window, as it will log all the "chat" running proxied to/from Ollama.

```bash
swift build
HOST=192.168.64.1 PORT=11434 swift run
```

### Run a codex container in the current directory

The following command runs a "throwaway" `codex` container with the current directory as 'workdir'

```bash
container run --rm -it --mount type=bind,src="$(pwd)",dst=/workdir codex
```

You can name the container using the '--name' argument:

```bash
container run --rm -it --name "my-codex" --mount type=bind,src="$(pwd)",dst=/workdir codex
```

To start a `bash` within the same (running!) container, you can use

```bash
container exec -it "my-codex" bash
```

If you want to keep your session/chat history over multiple container restarts/runs, do not remove the container after termination (=omit `--rm` argument and make sure you give it a unique name – here derived from the current directory):

```bash
container run -it --name "codex-`basename $PWD`" --mount type=bind,src="$(pwd)",dst=/workdir codex
```

This is basically a shortcut for two commands below: create a new named container and start it (interactively)

```bash
container create -t --name "codex-`basename $PWD`" --mount type=bind,src="$(pwd)",dst=/workdir codex
container start -i "codex-`basename $PWD`"
```

After quitting the current session in the container using CTRL+D, you can start the container again:

```bash
container start -i "codex-`basename $PWD`"
```

To remove the container later after you finished working with it, use the following command to remove of it:

```bash
container rm "codex-`basename $PWD`"
```

To check what containers (even stopped ones) are lingering around use:

```bash
container ls -a
```

If you want to run more CPU and memory hungry builds within the codex container, you can specify CPU and memory when starting:

```bash
container run -it -c 6 -m 8G --name "codex-`basename $PWD`" --mount type=bind,src="$(pwd)",dst=/workdir codex
```

### Running OpenAI models in an isolated container

If you really want to connect to an OpenAI model, you have to connect codex within the container to OpenAI using either an API key or a device key. This means, you have to preserve the configuration within the container.

Basically we will create a container keeping the configuration around (auth.json generated by `codex login`), then always restart the same container as long as we need it.

1. Create the desired container, launching bash upon start:

    ```bash
    container run -it --name "codex-openai-`basename $PWD`" --mount type=bind,src="$(pwd)",dst=/workdir codex-swift bash
    ```

2. Within the containers shell login to codex using device auth:

    ```bash
    codex login --device-auth
    ```

3. After successfull login you can launch codex using the OpenAI models:

   ```bash
   codex --dangerously-bypass-approvals-and-sandbox
   ```

To restart the container later again, start the container:

```bash
container start -i "codex-openai-`basename $PWD`" 
```

and launch:

```bash
codex --dangerously-bypass-approvals-and-sandbox
```

Remove the container to destroy the device configuration

```bash
container rm "codex-openai-`basename $PWD`"
```

#### Store auth.json in macOS Keychain

After you complete the OpenAI device-auth login flow, you may want to keep a copy of the device authorization tokens in your macOS Keychain. This is only relevant when `auth.json` exists (device-auth creates it). The file lives at `/root/.codex/auth.json` inside the container and contains sensitive tokens. Use `codex-auth-keychain.sh` to move it into the Keychain:

```bash
./codex-auth-keychain.sh store-from-container "codex-openai-`basename $PWD`"
```

If you created a fresh container and want to restore the authorization from the Keychain, use:

```bash
./codex-auth-keychain.sh load-to-container "codex-openai-`basename $PWD`"
```

Notes:
- The container must be running for both commands.
- The default path is `/root/.codex/auth.json` unless you pass an explicit path.
