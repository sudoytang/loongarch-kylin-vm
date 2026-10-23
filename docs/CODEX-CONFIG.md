# Codex config example (DeepSeek / OpenAI-compatible)

Codex CLI talks to an OpenAI-shaped Chat Completions API. On a China network, DeepSeek is a practical backend.

Create `~/.codex/config.toml` (paths below are examples; adjust model names to whatever your provider documents):

```toml
# Minimal OpenAI-compatible setup (DeepSeek)
# Docs: https://api-docs.deepseek.com/

model = "deepseek-chat"
model_provider = "deepseek"

[model_providers.deepseek]
name = "DeepSeek"
base_url = "https://api.deepseek.com/v1"
env_key = "DEEPSEEK_API_KEY"
wire_api = "chat"

# Optional second provider pointing at any OpenAI-compatible gateway
# [model_providers.openai_compat]
# name = "OpenAI-compatible"
# base_url = "https://your-gateway.example/v1"
# env_key = "OPENAI_API_KEY"
# wire_api = "chat"
```

Export the key before starting Codex:

```bash
export DEEPSEEK_API_KEY=sk-...
# or: export OPENAI_API_KEY=...
```

On this old-world LoongArch build, sandbox/Landlock support is limited. For interactive use on a trusted machine the friend typically runs with full access:

```bash
codex --dangerously-bypass-approvals-and-sandbox
```

Do **not** ship real API keys in this repo. Keep keys in the environment or in a local file that is gitignored.
