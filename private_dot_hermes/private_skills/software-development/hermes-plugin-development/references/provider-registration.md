# Which hook registers which backend

All hooks live on `PluginContext`; the table is derived from
`hermes_cli/plugins_registrars.py`. Each entry is `(ctx method, ABC, config key that selects it)`.

| ctx method | ABC | selected by | notes |
|---|---|---|---|
| `register_tts_provider` | `agent.tts_provider.TTSProvider` | `tts.provider` | dispatched only when the value is neither a built-in nor a `tts.providers.<name>: type: command` entry |
| `register_transcription_provider` | `agent.transcription_provider.TranscriptionProvider` | `stt.provider` | same precedence rules as TTS |
| `register_browser_provider` | `agent.browser_provider.BrowserProvider` | `browser.cloud_provider` | consulted by `tools.browser_session_cloud.get_cloud_provider` |
| `register_terminal_environment_provider` | `agent.terminal_env_provider.TerminalEnvironmentProvider` | `terminal.backend` | built-in backends (local, docker, modal, daytona, vercel_sandbox, ssh) are rejected |
| `register_delegation_provider` | `agent.delegation_provider.DelegationProvider` | `delegation.backend` | may add per-task schema parameters; core keeps the subagent lifecycle |
| `register_secret_source` | `agent.secret_sources.base.SecretSource` | `secrets.<name>.enabled` | runs inside `load_hermes_dotenv()`; plugin sources are re-pulled after discovery |

## Dispatch rules that decide whether a plugin is ever called

1. **Built-in names win.** The registry refuses a colliding plugin name with a warning; the
   plugin still *loads*, which is why "enabled but ignored" has no error to grep for.
2. **Config wins over install.** A `tts.providers.<name>: type: command` entry with the same
   name takes precedence over a plugin — config is more local than an install.
3. **Exact registered name only.** The configured value is lowercased and stripped before
   lookup; anything unmatched falls through to the built-in default (for TTS, Edge), which
   hides the mistake.

## Two plugin shapes seen in the wild

- **Context hook plugin** (the common case): `def register(ctx)` in `__init__.py`, provider
  instance registered there. `kind: standalone`.
- **Model-provider plugin**: registers a `ProviderProfile` at module import (no `ctx`), and is
  declared `kind: model-provider`; discovery treats it as its own category and can auto-detect
  it from the `__init__.py` source when `kind` is omitted.

## Minimal check that a provider is reachable

```python
from hermes_cli.plugins import _ensure_plugins_discovered
_ensure_plugins_discovered()
from agent.tts_registry import get_provider
p = get_provider("<name>")
assert p is not None, "not registered"
print(p.name, p.is_available(), p.streams_pcm, getattr(p, "stream_sample_rate", None), p.voice_compatible)
```

Run it with the Hermes install venv's python and `cwd=~/.hermes/hermes-agent` so the
`hermes_cli` / `agent` packages resolve.
