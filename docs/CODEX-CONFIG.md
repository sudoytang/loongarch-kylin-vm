# Codex config example (DeepSeek / OpenAI-compatible)

Codex CLI 0.163+ talks to providers over the **Responses** API (`wire_api = "responses"`).
`wire_api = "chat"` is rejected at startup. DeepSeek natively supports Responses
(`POST https://api.deepseek.com/responses`).

Create `~/.codex/config.toml`:

```toml
# Minimal DeepSeek setup for codex-cli 0.163.0 (old-world loongarch64 build)
# Docs: https://api-docs.deepseek.com/quick_start/agent_integrations/codex/

model = "deepseek-flash"          # or "deepseek-v4-pro"
model_provider = "deepseek"

[model_providers.deepseek]
name = "DeepSeek"
base_url = "https://api.deepseek.com"
env_key = "DEEPSEEK_API_KEY"
wire_api = "responses"
```

Export the key before starting Codex (do **not** put real keys in this repo):

```bash
export DEEPSEEK_API_KEY=sk-...
```

Optional: if Codex warns that model metadata for `deepseek-flash` is missing,
download DeepSeek's `models.json` into `~/.codex/models.json` and set
`model_catalog_json = "~/.codex/models.json"` (see DeepSeek Codex integration docs).

On this old-world LoongArch build, sandbox/Landlock support is limited. For
interactive use on a trusted machine the friend typically runs with full access:

```bash
codex --dangerously-bypass-approvals-and-sandbox
```

Non-interactive smoke / tool test:

```bash
codex --dangerously-bypass-approvals-and-sandbox exec --skip-git-repo-check \
  'Create /tmp/codex-proof.txt with one line OK' </dev/null
```

Redirect stdin from `/dev/null` when running under `nohup`/pipelines so Codex does
not block on "Reading additional input from stdin...".
