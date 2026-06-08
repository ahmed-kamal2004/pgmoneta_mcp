# pgmoneta-mcp-client

## Client Configuration File

The interactive client reads connection settings from a dedicated INI conf file.

Default path:

```text
/etc/pgmoneta-mcp/pgmoneta-mcp-client.conf
```

Expected format:

```ini
[pgmoneta_mcp_client]
url = http://localhost:8000/mcp
timeout = 30
model = qwen

[qwen]
provider = ollama
endpoint = http://localhost:11434
model = qwen2.5:3b
max_tool_rounds = 10

[gemma]
provider = llama.cpp
endpoint = http://localhost:8100/v1
model = ggml-org/gemma-3-4b-it-GGUF
max_tool_rounds = 10
```

The file must contain a `[pgmoneta_mcp_client]` section and may optionally
include one or more named LLM profile sections using the same keys as
`pgmoneta-mcp-server.conf`.

### `[pgmoneta_mcp_client]`

| Key | Required | Description |
| :--- | :--- | :--- |
| `url` | Yes | Full MCP endpoint used by the client. This should point to the server's `/mcp` route, for example `http://localhost:8000/mcp`. |
| `timeout` | No | Connection and request timeout in seconds. Defaults to `30` when omitted. |
| `model` | No* | Default named LLM profile used for natural-language requests. Required when more than one LLM profile is configured. |

### `[<llm-name>]`

| Key | Required | Description |
| :--- | :--- | :--- |
| `provider` | Yes | LLM backend. Supported values match the server configuration: `ollama`, `llama.cpp`, `ramalama`, and `vllm`. |
| `endpoint` | Yes | LLM server URL. For `llama.cpp`, `ramalama`, and `vllm`, configure either the server root URL or the OpenAI-compatible `/v1` URL. |
| `model` | Yes | Model name or ID to use for tool selection. |
| `max_tool_rounds` | No | Accepted for compatibility with the server's `[llm]` block. Defaults to `10`. |

The section name is the client-visible profile name. Use `/model [llm-name]` to
switch between these profiles at runtime.

Example with comments:

```ini
[pgmoneta_mcp_client]
# Full MCP endpoint used by the client
url = http://localhost:8000/mcp

# Timeout in seconds for connect, list_tools, and call_tool operations
timeout = 30
model = qwen

[qwen]
# Optional LLM profile for natural-language tool execution
provider = ollama
endpoint = http://localhost:11434
model = qwen2.5:3b
max_tool_rounds = 10

[gemma]
provider = llama.cpp
endpoint = http://localhost:8100/v1
model = ggml-org/gemma-3-4b-it-GGUF
max_tool_rounds = 10
```

## Interactive Shell

Start the client:

```bash
./pgmoneta-mcp-client -c pgmoneta-mcp-client.conf -u pgmoneta-mcp-users.conf
```

The prompt uses the selected username and current MCP target URL:

```text
admin@localhost:8000/mcp$ 
```

The startup header shows the current MCP target URL and active model profile.
The MCP line uses a green tick or red cross based on MCP server reachability,
while the model line uses its own green tick or red cross based on active model
endpoint reachability. The same header is refreshed after `/clear`, `/connect`,
`/disconnect`, `/reload`, and `/model [name]`. The prompt follows the same
current MCP target URL, even after a failed `/connect` or after `/disconnect`.

## Commands

```text
/clear                Clear the terminal and reprint the status header
/connect [url]        Connect to [url] or the configured MCP server target
/disconnect           Disconnect from the current MCP server target
/reload               Reconnect with the original client URL and model configuration
/list-models          List configured LLM profiles in a table
/model
/model gemma
/help                 Show basic usage
/user                 Switch to user mode (default)
/developer            Switch to developer mode
/tools                List available tools
/exit or /quit        Exit the client
```

The client uses `url` from `pgmoneta-mcp-client.conf` as its default MCP
endpoint target, derives the tool `server` argument from that configured
endpoint's host name, and injects `username` from the users file passed with
`-u` / `--users`. If the users file contains multiple admin usernames, the
client asks you to choose one at startup. For any remaining parameters, the
client prompts from the tool schema. Required fields must be filled in, while
optional fields can be skipped by pressing Enter.

`/connect [url]` switches the current MCP target URL. If `[url]` is omitted,
the client reconnects to the configured target from
`pgmoneta-mcp-client.conf`. If the client is already connected, it disconnects
before reconnecting.

`/reload` disconnects the current session, restores the MCP target URL and
active `/model` selection from the client configuration loaded at startup, and
reconnects with that original state.

`/clear` clears the current terminal when the client is attached to a real
terminal and then reprints the current status header.

`/list-models` prints the configured LLM profiles as an aligned table with the
columns `Name`, `Model`, and `Provider`.

The client starts in `/user` mode. In this mode it accepts natural-language
requests. If one or more named LLM profiles are present, it sends the current
`/tools` definitions to the active LLM, asks it to choose the best matching
tool, and then executes that tool with the generated JSON arguments. For
example, `List backups on primary server` maps to
`list_backups {"server":"primary"}` before execution.

The `metric` tool accepts a metric name and optional label filters as JSON. Use
`attributes` to match Prometheus labels exactly:

```text
metric {"name":"pgmoneta_version"}
metric {"name":"pgmoneta_retention_server","attributes":{"server":"primary"}}
metric {"name":"pgmoneta_retention_server","labels":{"server":"primary"}}
```

`attributes` and `labels` are equivalent aliases; provide only one of them. If
you omit the filter object, the tool returns all matching metric samples. In
user mode, a single matching metric is shown as just its value. In developer
mode, the full Prometheus sample line is printed, for example:

```text
pgmoneta_version{version="0.22.0"} 1
```

Use `/developer` to switch to developer mode. In this mode the input must be an
explicit tool call such as `list_backups {"server":"primary"}`, and the client
prints the full JSON response instead of the human-readable translation used in
user mode.

Non-empty input lines are recorded in history as entered. If the first
non-whitespace character is `#`, the line is treated as a comment, is still
recorded in history, does not execute, and immediately shows a fresh prompt.

The shell uses readline-style editing, so standard history and cursor shortcuts
such as Arrow Up / Down, Home / End, Ctrl+A / E, Ctrl+B / F, Ctrl+R, Ctrl+U / K,
and Ctrl+Y work directly in the input prompt. Slash commands support Tab
completion, so typing `/ex` and pressing Tab completes to `/exit`. The `/model`
command also supports Tab completion for configured LLM profile names. Command
history is loaded from and saved to
`~/.pgmoneta-mcp/pgmoneta-mcp-client.history`, and the client keeps at most the
latest 1000 entries. Press Ctrl+C once to display `Press Ctrl+c again to quit`;
press Ctrl+C again within 2 seconds to exit, otherwise the pending quit state is
cleared automatically. Tool errors are printed in the session and do not
terminate the client. When a tool response is JSON, the client pretty-prints it
and translates known pgmoneta fields such as file sizes, LSNs, compression,
encryption, command codes, and error codes into more readable values.

Examples:

```bash
admin@localhost:8000/mcp$ /clear
admin@localhost:8000/mcp$ /disconnect
admin@localhost:8000/mcp$ /connect
admin@localhost:8000/mcp$ /connect http://localhost:8200/mcp
admin@localhost:8200/mcp$ /reload
admin@localhost:8200/mcp$ /disconnect
admin@localhost:8200/mcp$ /connect
admin@localhost:8000/mcp$ /list-models
admin@localhost:8000/mcp$ /user
admin@localhost:8000/mcp$ /model
admin@localhost:8000/mcp$ /model gemma
admin@localhost:8000/mcp$ List backups on primary server
admin@localhost:8000/mcp$ metric {"name":"pgmoneta_version"}
admin@localhost:8000/mcp$ /developer
admin@localhost:8000/mcp$ list_backups {"server":"primary"}
admin@localhost:8000/mcp$ annotate_backup {"server":"primary","backup_id":"newest","action":"add","key":"mykey","comment":"mycomment"}
admin@localhost:8000/mcp$ annotate_backup {"server":"primary","backup_id":"newest","action":"update","key":"mykey","comment":"mynewcomment"}
admin@localhost:8000/mcp$ annotate_backup {"server":"primary","backup_id":"newest","action":"remove","key":"mykey"}
admin@localhost:8000/mcp$ get_backup_info {"server":"primary","backup_id":"newest"}
admin@localhost:8000/mcp# metric {"name":"pgmoneta_retention_server","attributes":{"server":"primary"}}
```
