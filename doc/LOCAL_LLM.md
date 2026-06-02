# Local LLM Installation

This guide focuses on installing and configuring a local LLM runtime for pgmoneta MCP.
It is intentionally scoped to local setup and does not cover chat examples or internal
implementation details.

## Scope

This guide covers:

* Installing Ollama, RamaLama, llama.cpp, or vLLM
* Downloading and validating a model
* Configuring the `[llm]` section in `pgmoneta-mcp.conf`
* Configuring one or more named LLM profiles in `pgmoneta-mcp-client.conf`

## Selecting a model

When choosing an LLM for **pgmoneta_mcp**, keep these key concepts in mind regardless of which provider you choose:

1. **Instruct vs. Base**: You must use a model fine-tuned for instruction following or chat (usually labeled `Instruct` or `Chat`). Base models are not trained to follow instructions and will fail at tool calling.
2. **Quantization**: Models are compressed ("quantized") to fit into consumer hardware. The default standard is **Q4** (4-bit quantization), which provides an excellent balance of speed, size, and reasoning quality.
3. **Hardware Limits**: The model's listed file size indicates the *minimum* RAM needed simply to load its weights. Actual runtime usage will be 20-30% higher because the runtime allocates memory for context caching and inference buffers.

## Setups & Storage Management

To prevent running out of disk space ("No space left on device") and ensure you have the hardware to run models, we define three standard setups:

* **Small setup**: Aimed at standard laptops. Uses ~3B parameter models requiring 2-4GB of RAM/VRAM and disk space. E.g., `llama3.2:3b`.
* **Best setup**: The recommended balance of size and quality. Requires 8-10GB of RAM/VRAM and disk space. E.g., `granite-code:8b` or `llama3.1:8b`.
* **Full setup**: For powerful workstations or servers (32GB+ RAM/VRAM). Uses large models requiring 40GB+ of disk space. E.g., `llama3.1:70b`.

**Important**: Large models consume significant storage space. By default, runtimes store downloaded model files in standard cache directories (like `~/.ollama` or `~/.cache/huggingface`). If your root drive (`/`) has limited space, you **must** override the storage/cache directory to a larger volume. Instructions to do this are provided for each backend below.

### Model Compatibility Matrix

The model must support **tool calling** (function calling) to work with pgmoneta MCP tools.

| Model | Size | RAM Needed | Ollama | RamaLama | llama.cpp | vLLM | Notes |
| :---- | :--- | :--------- | :----- | :------- | :-------- | :--- | :---- |
| `granite-code` | ~5.0 GB | ~8 GB | Yes | Yes | Yes (GGUF) | Yes | **Recommended**. Built for coding and tool-calling |
| `gemma4:9b` | ~6.2 GB | ~10 GB | Yes | Yes | Yes (GGUF) | Yes | **Apache 2.0**. Excellent tool-calling and reasoning |
| `llama3.1:8b` | ~4.7 GB | ~8 GB | Yes | Yes | Yes (GGUF) | Yes | Best balance of capability and size |
| `llama3.2:3b` | ~2.0 GB | ~4 GB | Yes | Yes | Yes (GGUF) | Yes | Lightweight option for limited hardware |
| `qwen2.5:7b` | ~4.7 GB | ~8 GB | Yes | Yes | Yes (GGUF) | Yes | Excellent tool calling capabilities |
| `mistral:7b` | ~4.1 GB | ~8 GB | Yes | Yes | Yes (GGUF) | Yes | Strong performance for open-source models |

## MCP client

The MCP client is called `pgmoneta-mcp-client`, and its configuration in `pgmoneta-mcp-client.conf` is

```ini
[pgmoneta_mcp_client]
url = http://localhost:6432/mcp
timeout = 30
model = gemma

[qwen]
provider = ollama
endpoint = http://localhost:11434
model = qwen2.5:3b
max_tool_rounds = 10

[gemma]
provider = llama.cpp
endpoint = http://localhost:8100/v1
model = ggml-org/gemma-4-E4B-it-GGUF
```

for example.

Start the client by

```sh
./pgmoneta-mcp-client -c pgmoneta-mcp-client.conf -u pgmoneta-mcp-users.conf
```

to enter its interactive mode. Use `/model` to inspect the active profile and
`/model [name]` to switch between the configured profiles at runtime. Press Tab
after `/model ` to complete the available profile names. The client header shows
the current MCP target URL and active profile, with independent green tick /
red cross indicators for MCP reachability and active model endpoint
reachability. `/clear` clears the current terminal when the client is attached
to a real terminal and then reprints that header. `/connect [url]` can switch
the current MCP target URL at runtime, while `/connect` without a URL resets it
to the configured default. `/reload` disconnects the current session, restores
both the original MCP URL and the startup `/model` selection, and reconnects
with that configuration. Use `/list-models` to print the configured client
profiles as an aligned table with `Name`, `Model`, and `Provider` columns.

## Ollama

[Ollama](https://ollama.com) is the recommended provider for running open-source models locally. It provides a simple CLI and API for downloading, managing, and serving LLM models.

### Basic Setup (Rocky Linux 10)

Install Ollama using the official script:

```sh
curl -fsSL https://ollama.com/install.sh | sh
```

Start the Ollama server as a background service:

```sh
ollama serve
```

### Storage Management

By default, Ollama stores models in `/usr/share/ollama/.ollama/models` (or `~/.ollama/models` for user installs). To avoid filling up your root partition, redirect this directory using `OLLAMA_MODELS`:

```sh
export OLLAMA_MODELS=/mnt/ai/ollama/models
# For systemd service:
# systemctl set-environment OLLAMA_MODELS=/mnt/ai/ollama/models
# systemctl restart ollama
```

### Precise Commands

**Small setup** (Laptop friendly):
```sh
OLLAMA_MODELS=/mnt/ai/ollama/models ollama pull llama3.2:3b
```

**Best setup** (Recommended):
```sh
OLLAMA_MODELS=/mnt/ai/ollama/models ollama pull granite-code:8b
```

**Full setup** (Workstation only):
```sh
OLLAMA_MODELS=/mnt/ai/ollama/models ollama pull llama3.1:70b
```

### Example

```ini
[llm]
provider = ollama
endpoint = http://localhost:11434
model = granite-code:8b
max_tool_rounds = 10
```

## llama.cpp

[llama.cpp](https://github.com/ggml-org/llama.cpp) provides direct control over hardware and inference settings for running LLMs locally.

### Basic Setup (Rocky Linux 10)

You must download the `llama-server` binary and the model file manually.

```sh
dnf install wget
```

Download the latest `llama-server` from the [official releases](https://github.com/ggml-org/llama.cpp/releases).

If you build `llama.cpp` from source, the server binary is typically available as
`./build/bin/llama-server`.

### Storage Management

llama.cpp requires you to download the `.gguf` files manually. Simply download these files directly to your preferred high-capacity drive (e.g., `/mnt/ai/models/`) to avoid disk exhaustion.

### Precise Commands

**Small setup** (Laptop friendly):
```sh
wget https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf -P /mnt/ai/models/
llama-server --model /mnt/ai/models/Llama-3.2-3B-Instruct-Q4_K_M.gguf --port 8080 --ctx-size 8192
```

**Best setup** (Recommended):
```sh
wget https://huggingface.co/bartowski/granite-3.0-8b-instruct-GGUF/resolve/main/granite-3.0-8b-instruct-Q4_K_M.gguf -P /mnt/ai/models/
llama-server --model /mnt/ai/models/granite-3.0-8b-instruct-Q4_K_M.gguf --port 8080 --ctx-size 8192
```

**Full setup** (Workstation only):
```sh
wget https://huggingface.co/bartowski/Meta-Llama-3.1-70B-Instruct-GGUF/resolve/main/Meta-Llama-3.1-70B-Instruct-Q4_K_M.gguf -P /mnt/ai/models/
llama-server --model /mnt/ai/models/Meta-Llama-3.1-70B-Instruct-Q4_K_M.gguf --port 8080 --ctx-size 8192
```

### Copy/paste llama.cpp setup for pgmoneta MCP

The following commands mirror a practical setup used in production-like local environments.

Gemma:

```sh
LLAMA_CACHE=/mnt/ai/llama.cpp/  llama-server \
  -hf ggml-org/gemma-4-E4B-it-GGUF \
  --alias "ggml-org/gemma-4-E4B-it-GGUF" \
  --port 8100 \
  --ctx-size 65536 \
  --reasoning-budget 512 \
  -t 4
```

Qwen Coder:

```sh
LLAMA_CACHE=/mnt/ai/llama.cpp/  llama-server \
  -hf unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF \
  --alias "unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF" \
  --port 8100 \
  --ctx-size 65536 \
  --reasoning-budget 512 \
  -t 4
```

Run from a local build:

```sh
LLAMA_CACHE=/mnt/ai/llama.cpp/ ./build/bin/llama-server \
  -hf ggml-org/gemma-4-E4B-it-GGUF \
  --port 8100 \
  --ctx-size 65536 \
  --reasoning-budget 512 \
  -t 4
```

Run from a system-wide installation with a downloaded GGUF file:

```sh
llama-server \
  -m ~/.cache/huggingface/hub/models--ggml-org--gemma-4-E4B-it-GGUF/snapshots/*/gemma-4-E4B-it-Q4_K_M.gguf \
  --alias "ggml-org/gemma-4-E4B-it-GGUF" \
  --port 8100 \
  --ctx-size 65536 \
  --reasoning-budget 512 \
  -t 4
```

The endpoint for this setup is `http://localhost:8100/v1`.

### Example

```ini
[llm]
provider = llama.cpp
endpoint = http://localhost:8080/v1
model = granite-3.0-8b-instruct-Q4_K_M.gguf
max_tool_rounds = 10
```

### Multi-profile MCP client configuration (qwen, gemma, coder)

Use named client profiles to switch quickly between models while staying connected to
the same MCP server.

```ini
[pgmoneta_mcp_client]
url = http://localhost:6432/mcp
timeout = 30
model = gemma

[qwen]
provider = ollama
endpoint = http://localhost:11434
model = qwen2.5:3b
max_tool_rounds = 10

[gemma]
provider = llama.cpp
endpoint = http://localhost:8100/v1
model = ggml-org/gemma-4-E4B-it-GGUF
max_tool_rounds = 10

[coder]
provider = llama.cpp
endpoint = http://localhost:8100/v1
model = unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF
max_tool_rounds = 10
```

Switch profiles at runtime in `pgmoneta-mcp-client`:

```text
/model gemma
/model qwen
/model coder
```

## RamaLama

[RamaLama](https://ramalama.ai) is an open-source command-line interface and unified AI gateway that simplifies the deployment and inference of AI models using containerization (Podman or Docker).

### Basic Setup (Rocky Linux 10)

It is available natively on RPM-based distributions:

```sh
dnf install ramalama
```

### Storage Management

RamaLama pulls layers natively using container tooling. By default this utilizes your system's temporary directory and container storage. To change the storage path to a larger drive (e.g., `/mnt/ai/ramalama`), use the `--store` flag.

### Precise Commands

**Small setup** (Laptop friendly):
```sh
ramalama --store /mnt/ai/ramalama serve llama3.2:3b
```

**Best setup** (Recommended):
```sh
ramalama --store /mnt/ai/ramalama serve granite-code:8b
```

**Full setup** (Workstation only):
```sh
ramalama --store /mnt/ai/ramalama serve llama3.1:70b
```

The default endpoint is `http://localhost:8080`. In pgmoneta MCP configuration
you can use either `http://localhost:8080` or `http://localhost:8080/v1` for
OpenAI-compatible providers such as RamaLama.

### Example

```ini
[llm]
provider = ramalama
endpoint = http://localhost:8080/v1
model = granite-code:8b
max_tool_rounds = 10
```

## vLLM

[vLLM](https://github.com/vllm-project/vllm) is a high-throughput and memory-efficient engine for LLMs that natively exposes an OpenAI-compatible API.

### Install

Install vLLM via pip (a virtual environment is recommended):

```sh
pip install vllm
```

### Storage Management

vLLM utilizes the standard Hugging Face cache directory (`~/.cache/huggingface`). Set the `HF_HOME` environment variable to a large mounted drive to prevent disk space exhaustion.

### Precise Commands

**Small setup** (Laptop friendly):
```sh
HF_HOME=/mnt/ai/huggingface python -m vllm.entrypoints.openai.api_server \
  --model meta-llama/Llama-3.2-3B-Instruct \
  --port 8000
```

**Best setup** (Recommended):
```sh
HF_HOME=/mnt/ai/huggingface python -m vllm.entrypoints.openai.api_server \
  --model ibm-granite/granite-3.0-8b-instruct \
  --port 8000
```

**Full setup** (Workstation only):
```sh
HF_HOME=/mnt/ai/huggingface python -m vllm.entrypoints.openai.api_server \
  --model meta-llama/Meta-Llama-3.1-70B-Instruct \
  --port 8000 \
  --tensor-parallel-size 4
```

Verify it is running:

```sh
curl http://localhost:8000/v1/models
```

### Example

```ini
[llm]
provider = vllm
endpoint = http://localhost:8000/v1
model = ibm-granite/granite-3.0-8b-instruct
max_tool_rounds = 10
```

### Configuration properties

| Property | Default | Required | Description |
| :------- | :------ | :------- | :---------- |
| provider |  | Yes | The LLM provider backend (`ollama`, `llama.cpp`, `ramalama` or `vllm`) |
| endpoint |  | Yes | The URL of the LLM inference server. For `llama.cpp`, `ramalama`, and `vllm`, either the server root URL or the OpenAI-compatible `/v1` URL can be configured. |
| model |  | Yes | The model name to use for inference |
| max_tool_rounds | 10 | No | Maximum tool-calling iterations per user prompt |

## Quick verification

1. Confirm your LLM server is running:

For **Ollama**:
```sh
curl http://localhost:11434/
```

For **llama.cpp**:
```sh
curl http://localhost:8080/health
```

For **RamaLama**:
```sh
curl http://localhost:8080/v1/models
```

For **vLLM**:
```sh
curl http://localhost:8000/v1/models
```

2. Start pgmoneta MCP with your config file:

```sh
pgmoneta-mcp-server -c pgmoneta-mcp.conf -u pgmoneta-mcp-users.conf
```

3. From your MCP client, ask for backup information to verify end-to-end setup.
