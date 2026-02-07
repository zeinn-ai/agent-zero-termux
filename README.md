# Agent Zero for Termux (Android)

A port of [Agent Zero](https://github.com/agent0ai/agent-zero) that runs natively on Android using Termux, without requiring Docker.

## Overview

Agent Zero is a powerful AI agent framework that uses LLMs to perform various tasks including code execution, web search, file manipulation, and more. The official version requires Docker, which doesn't run on Android. This port removes the Docker dependency and adapts the framework to run directly on Termux.

### What's Different from Official Agent Zero?

| Feature | Official (Docker) | Termux Port |
|---------|------------------|-------------|
| Runtime | Docker container | Native Termux |
| Code Execution | SSH to container | Local PTY shell |
| SearXNG | Containerized | Optional local/external |
| Browser Agent | Playwright | Disabled (no display) |
| Speech-to-Text | Whisper local | API-based only |
| Text-to-Speech | Kokoro local | Disabled |
| Vector Store | FAISS | ChromaDB |
| Embeddings | Local models | API-based |

## Requirements

- Android device (ARM64 recommended)
- [Termux](https://termux.dev/) installed (from F-Droid, not Play Store)
- At least 4GB free storage
- 4GB+ RAM recommended
- Internet connection
- API key for an LLM provider (OpenAI, Anthropic, OpenRouter, etc.)

## Quick Installation

### One-Line Install

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_REPO/agent-zero-termux/main/install.sh | bash
```

### Manual Installation

1. **Install Termux** from [F-Droid](https://f-droid.org/packages/com.termux/)

2. **Update Termux packages:**
   ```bash
   pkg update && pkg upgrade -y
   ```

3. **Clone this repository:**
   ```bash
   pkg install git
   git clone https://github.com/YOUR_REPO/agent-zero-termux.git
   cd agent-zero-termux
   ```

4. **Run the installer:**
   ```bash
   bash install.sh
   ```

5. **Configure API keys:**
   ```bash
   nano ~/agent-zero/.env
   ```

6. **Start Agent Zero:**
   ```bash
   cd ~/agent-zero
   ./start.sh
   ```

7. **Open in browser:** http://localhost:8080

## Installation Options

```bash
# Full installation (default)
bash install.sh

# Skip SearXNG (use external search instance)
bash install.sh --skip-searxng

# Minimal installation (skip optional packages)
bash install.sh --minimal

# Show help
bash install.sh --help
```

## Configuration

Edit `~/agent-zero/.env` to configure:

```bash
# LLM Provider API Keys (at least one required)
OPENAI_API_KEY=sk-...
ANTHROPIC_API_KEY=sk-ant-...
OPENROUTER_API_KEY=sk-or-...

# Web UI Settings
WEB_UI_HOST=0.0.0.0
WEB_UI_PORT=8080

# Search Engine (local or external SearXNG)
SEARXNG_URL=http://localhost:8888
# Or use external: SEARXNG_URL=https://searx.be

# Authentication (optional but recommended)
AUTH_LOGIN=admin
AUTH_PASSWORD=your_secure_password
```

### LLM Provider Configuration

Agent Zero uses LiteLLM for provider abstraction. Configure your preferred provider:

**OpenAI:**
```bash
OPENAI_API_KEY=sk-...
```

**Google AI Studio (Gemini):**
Get your API key from [Google AI Studio](https://aistudio.google.com/).
```bash
GEMINI_API_KEY=AIzaSy...
# Use model names with 'gemini/' prefix:
# - gemini/gemini-1.5-pro
# - gemini/gemini-1.5-flash
# - gemini/gemini-2.0-flash-exp
```

**Anthropic:**
```bash
ANTHROPIC_API_KEY=sk-ant-...
```

**OpenRouter (multiple models):**
```bash
OPENROUTER_API_KEY=sk-or-...
```

**Ollama (local models):**
```bash
OLLAMA_BASE_URL=http://localhost:11434
```

**Azure OpenAI:**
```bash
AZURE_API_KEY=...
AZURE_API_BASE=https://your-resource.openai.azure.com/
AZURE_API_VERSION=2024-02-15-preview
```

## Usage

### Starting Agent Zero

```bash
cd ~/agent-zero
./start.sh
```

Or start just the web UI:
```bash
./run_termux.sh
```

### Accessing the Web UI

- **Local browser:** http://localhost:8080
- **From other devices:** http://YOUR_PHONE_IP:8080

To find your phone's IP:
```bash
ifconfig wlan0 | grep 'inet '
```

### Using Agent Zero

1. Open the web UI in your browser
2. Configure your LLM provider in Settings
3. Start chatting with the agent
4. The agent can:
   - Execute Python, Node.js, and shell commands
   - Search the web
   - Read and write files
   - Remember information
   - Create sub-agents for complex tasks

## Features

### Code Execution

Agent Zero can execute code in multiple runtimes:

- **Python:** Using IPython
- **Node.js:** Using the node runtime
- **Shell:** Native Termux bash

Example prompts:
- "Write a Python script to calculate fibonacci numbers"
- "Create a bash script to organize my files"
- "Run npm init to create a new Node.js project"

### Web Search

Uses SearXNG for privacy-focused web search:
- Local SearXNG instance (if installed)
- External SearXNG instance (configurable)
- Fallback to DuckDuckGo API

### Memory & Knowledge

- Persistent memory across sessions
- Import custom knowledge files (PDF, TXT, MD)
- Context-aware responses based on history

### Multi-Agent System

- Create sub-agents for complex tasks
- Hierarchical task delegation
- Specialized agent roles

## Troubleshooting

### Common Issues

**1. Installation fails with "package not found"**
```bash
pkg update && pkg upgrade -y
termux-change-repo  # Try a different mirror
```

**2. Python packages fail to build**
```bash
pkg install build-essential clang rust
pip install --upgrade pip wheel setuptools
```

**3. "Permission denied" errors**
```bash
termux-setup-storage  # Grant storage access
```

**4. Web UI not accessible**
```bash
# Check if port is in use
netstat -tlnp | grep 8080

# Try a different port
WEB_UI_PORT=9090 ./start.sh
```

**5. Out of memory during installation**
- Close other apps
- Use swap (if rooted): `swapon /path/to/swapfile`
- Use `--minimal` flag

**6. Slow response times**
- Use a faster LLM (GPT-3.5 instead of GPT-4)
- Reduce context window size in settings
- Close other Termux sessions

### Getting Logs

```bash
# View recent logs
cat ~/agent-zero/logs/*.html | tail -100

# View in real-time
tail -f ~/agent-zero/logs/latest.log
```

## Limitations

Compared to the Docker version, this Termux port has some limitations:

1. **No Browser Agent:** Playwright doesn't work on Termux (no display server)
2. **No Local Whisper:** Speech-to-text uses API only
3. **No Local TTS:** Text-to-speech is disabled
4. **Limited OCR:** Tesseract may not be fully functional
5. **Smaller Models Only:** Heavy ML models may not fit in memory
6. **No Docker Tools:** Container-related features are disabled

## Updating

To update to the latest version:

```bash
cd ~/agent-zero
git pull
./run_termux.sh  # Will update dependencies if needed
```

Or reinstall:
```bash
cd ~/agent-zero-termux
bash install.sh
```

## Advanced Configuration

### Running on Boot

Create a Termux:Boot script:
```bash
mkdir -p ~/.termux/boot
cat > ~/.termux/boot/start-agent-zero.sh << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
termux-wake-lock
cd ~/agent-zero && ./start.sh
EOF
chmod +x ~/.termux/boot/start-agent-zero.sh
```

### Using with Termux:Widget

Create a widget shortcut:
```bash
mkdir -p ~/.shortcuts
ln -s ~/agent-zero/start.sh ~/.shortcuts/Agent-Zero
```

### External SearXNG

Instead of running SearXNG locally, use a public instance:

```bash
# In .env
SEARXNG_URL=https://searx.be
# or
SEARXNG_URL=https://search.ononoki.org
```

### Custom Prompts

Customize agent behavior by editing prompts:
```bash
cd ~/agent-zero/prompts
cp -r default my-custom
# Edit files in my-custom/
# Then set in Settings: Prompts Subdirectory = my-custom
```

## Directory Structure

```
~/agent-zero/
├── .env                 # Configuration
├── .venv/               # Python virtual environment
├── start.sh             # Main launcher
├── run_termux.sh        # Web UI launcher
├── python/              # Core Python code
│   ├── helpers/         # Helper modules
│   │   ├── termux_runtime.py    # Termux detection
│   │   ├── shell_termux.py      # Termux shell handler
│   │   └── ...
│   └── tools/           # Agent tools
├── prompts/             # System prompts
├── memory/              # Agent memory storage
├── knowledge/           # Knowledge base
├── logs/                # Session logs
└── webui/               # Web interface
```

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test on Termux
5. Submit a pull request

## License

This project follows the same license as Agent Zero. See [LICENSE](LICENSE) for details.

## Acknowledgments

- [Agent Zero](https://github.com/agent0ai/agent-zero) - The original framework
- [Termux](https://termux.dev/) - Terminal emulator for Android
- [LiteLLM](https://github.com/BerriAI/litellm) - LLM provider abstraction

## Support

- GitHub Issues: Report bugs and request features
- Discord: [Agent Zero Discord](https://discord.gg/B8KZKNsPpj)
- Documentation: [Agent Zero Docs](https://github.com/agent0ai/agent-zero/tree/main/docs)
