# n8n with Local LLMs: Complete Setup Guide

**Document Version:** 1.0
**Last Updated:** December 30, 2025
**System:** WSL2 Ubuntu 24.04 with NVIDIA RTX 5070 Laptop GPU

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [System Hardware Analysis](#system-hardware-analysis)
3. [Best Local LLM Models for Coding (December 2025)](#best-local-llm-models-for-coding-december-2025)
4. [Local LLM Serving Options](#local-llm-serving-options)
5. [n8n Integration Methods](#n8n-integration-methods)
6. [Recommended Setup for This System](#recommended-setup-for-this-system)
7. [Step-by-Step Installation Guide](#step-by-step-installation-guide)
8. [Optimal Configuration](#optimal-configuration)
9. [Troubleshooting](#troubleshooting)
10. [Sources & References](#sources--references)

---

## Executive Summary

This document provides a comprehensive guide for setting up local LLM models with n8n on a high-performance WSL2 Ubuntu system featuring an NVIDIA RTX 5070 Laptop GPU. The goal is to enable secure, private AI-powered workflow automation without relying on external API services.

### Key Recommendations at a Glance

| Component | Recommendation |
|-----------|----------------|
| **LLM Server** | Ollama (native WSL2 install, not Docker) |
| **Primary Coding Model** | Qwen 2.5 Coder 7B (Q5_K_M quantization) |
| **Reasoning Model** | DeepSeek R1 Distill Qwen 8B (Q4_K_M) |
| **General Purpose** | NVIDIA Nemotron Nano 9B v2 (Q4_K_M) |
| **n8n Integration** | Native Ollama node with LangChain |
| **Context Length** | 8K-16K tokens (optimize for VRAM) |

---

## System Hardware Analysis

### Current System Specifications

| Component | Specification | AI Capability Assessment |
|-----------|---------------|-------------------------|
| **GPU** | NVIDIA GeForce RTX 5070 Laptop | Blackwell architecture, Compute 12.0 |
| **VRAM** | 8151 MiB (~8GB) | Capable of 7-9B models at Q4/Q5 quantization |
| **System RAM** | ~24GB | Excellent for CPU offloading if needed |
| **CPU** | Intel Core Ultra 9 285H (12 cores) | Strong hybrid architecture for inference fallback |
| **Storage** | 1TB SSD (~800GB free) | Ample space for multiple models |
| **OS** | Ubuntu 24.04.3 LTS (WSL2) | Native GPU passthrough support |
| **CUDA Driver** | 581.29 | Modern driver with Blackwell support |

### VRAM Budget Analysis

With 8GB VRAM, the practical allocation is:

```
Model Weights (Q4_K_M):     ~4.0 GB (for 7-8B models)
KV Cache (8K context):      ~1.5-2.0 GB
System/Framework Overhead:  ~1.0-1.5 GB
Available Headroom:         ~0.5-1.0 GB
```

**Practical Limits:**
- Maximum model size: **7-9B parameters** at Q4_K_M quantization
- Optimal context window: **8K-16K tokens** (16K uses ~7.2GB total)
- Expected performance: **40-50 tokens/second** for generation

### RTX 5070 Blackwell Architecture Advantages

The RTX 5070 Laptop GPU brings several advantages for local LLM inference:

1. **FP8 Support**: Native 8-bit floating point operations (2x memory efficiency vs FP16)
2. **Improved Quantization**: Enhanced support for lower-precision inference modes
3. **CUDA 12.0 Compute**: Latest compute capability for optimal llama.cpp performance
4. **GDDR7 Memory**: Higher bandwidth than previous generations

### Known Compatibility Issues

> **Warning:** As of late November 2025, there are documented issues with Ollama 0.12.x on Blackwell GPUs where GPU detection may fail, causing fallback to CPU mode. Monitor [Ollama GitHub Issue #13163](https://github.com/ollama/ollama/issues/13163) for updates.

**Requirements for Blackwell GPUs:**
- CUDA 12.8 or later
- PyTorch 2.7.0 or later
- Latest Ollama version (check for Blackwell fixes)

---

## Best Local LLM Models for Coding (December 2025)

### Tier 1: Top Recommendations for 8GB VRAM

#### 1. Qwen 2.5 Coder 7B (Primary Recommendation)

| Metric | Value |
|--------|-------|
| **HumanEval Score** | 88.4% (beats GPT-4's 87.1%) |
| **Languages Supported** | 92 programming languages |
| **VRAM Usage (Q5_K_M)** | ~4.5GB + context |
| **Context Window** | Up to 128K (use 8-16K for VRAM) |
| **Best For** | Code generation, completion, refactoring |

```bash
ollama pull qwen2.5-coder:7b
```

**Why Qwen 2.5 Coder:**
- Specifically optimized for coding tasks
- Matches GitHub Copilot performance
- Excellent at multi-file understanding
- Strong SQL performance (82.0% on Spider benchmark)
- Apache 2.0 license for commercial use

#### 2. NVIDIA Nemotron Nano 9B v2

| Metric | Value |
|--------|-------|
| **Coding Index** | Highest among 8GB-compatible models |
| **LiveCodeBench** | ~0.7 range (industry-leading) |
| **Architecture** | Hybrid Mamba-2 + MLP + Attention |
| **Languages** | 43 programming languages |
| **Best For** | Reasoning + coding combined tasks |

```bash
ollama pull nemotron-nano:9b
```

**Why Nemotron Nano:**
- Best-in-class for coding benchmarks at this size
- Toggleable reasoning mode (on/off)
- Trained from scratch by NVIDIA (not fine-tuned)
- Excellent for agentic workflows

#### 3. DeepSeek R1 Distill Qwen 8B

| Metric | Value |
|--------|-------|
| **Reasoning** | Chain-of-thought capabilities |
| **VRAM Usage (Q4_K_M)** | ~4.0GB + context |
| **Training** | Distilled from 671B R1 model |
| **Best For** | Complex reasoning, debugging, architecture |

```bash
ollama pull deepseek-r1:8b
```

**Why DeepSeek R1 Distill:**
- Exceptional step-by-step reasoning
- Distilled from the massive R1 671B model
- Excellent for debugging and problem-solving
- Updated version (R1-0528) with improved capabilities

### Tier 2: Alternative Options

#### Qwen3 8B (General + Coding)

- Outperforms Qwen 2.5 14B on 15 benchmarks
- 81.5 on AIME25 (math reasoning)
- 60.2 on LiveCodeBench
- Good for when you need balance between coding and general tasks

```bash
ollama pull qwen3:8b
```

#### Phi-4 14B (If context is critical)

- Microsoft's latest reasoning model
- Exceptional mathematical capabilities
- May require partial CPU offloading on 8GB VRAM

```bash
ollama pull phi4:14b
```

### Model Comparison Matrix

| Model | HumanEval | Reasoning | VRAM (Q4) | Speed | License |
|-------|-----------|-----------|-----------|-------|---------|
| Qwen 2.5 Coder 7B | 88.4% | Medium | ~4GB | Fast | Apache 2.0 |
| Nemotron Nano 9B | High | High | ~5GB | Fast | NVIDIA License |
| DeepSeek R1 8B | Good | Excellent | ~4GB | Medium | MIT |
| Qwen3 8B | Good | High | ~4.5GB | Fast | Apache 2.0 |
| CodeLlama 7B | 62.2% | Low | ~4GB | Fast | Llama License |

### Quantization Recommendations

For 8GB VRAM on coding tasks:

| Quantization | Size (7B) | Quality | Use Case |
|--------------|-----------|---------|----------|
| **Q5_K_M** | ~4.3GB | 95%+ | Recommended for coding |
| **Q4_K_M** | ~3.8GB | 92%+ | Memory-constrained |
| **Q6_K** | ~5.5GB | 97%+ | Critical accuracy needs |
| **Q8_0** | ~7GB | 99%+ | Near-lossless (tight fit) |

**Recommendation:** Use **Q5_K_M** for coding models when possible, as it provides the best quality-to-size ratio for code generation tasks. Fall back to Q4_K_M if running larger context windows.

---

## Local LLM Serving Options

### Option 1: Ollama (Recommended)

**Best For:** Developers, API integration, quick testing

| Aspect | Details |
|--------|---------|
| **Ease of Use** | Single command install and run |
| **API** | OpenAI-compatible REST API |
| **Backend** | llama.cpp (highly optimized) |
| **Model Format** | GGUF with automatic quantization |
| **GPU Support** | NVIDIA CUDA, AMD ROCm, Apple Metal |

**Pros:**
- Dead simple: `ollama run qwen2.5-coder:7b`
- Native n8n integration via Ollama node
- Automatic model management
- Low resource overhead
- Active development community

**Cons:**
- Limited concurrency (default 4 parallel requests)
- Not optimized for high-throughput production
- Blackwell GPU issues (as of late 2025)

### Option 2: LM Studio

**Best For:** Beginners, GUI preference, casual use

| Aspect | Details |
|--------|---------|
| **Interface** | Polished desktop GUI |
| **API** | OpenAI-compatible server |
| **Model Management** | Visual browser and download |
| **Platform** | Windows, macOS, Linux |

**Pros:**
- Beautiful, user-friendly interface
- Built-in model browser
- Document-based RAG support
- Good for exploration

**Cons:**
- Closed-source proprietary application
- More resource-intensive than Ollama
- Less suitable for automation pipelines

### Option 3: vLLM

**Best For:** Production deployments, high-throughput

| Aspect | Details |
|--------|---------|
| **Performance** | 3.2x throughput vs Ollama |
| **Technology** | PagedAttention for memory efficiency |
| **Scaling** | Tensor parallelism across GPUs |
| **API** | OpenAI-compatible |

**Pros:**
- Industry-leading inference speed
- 50%+ memory reduction via PagedAttention
- Excellent for concurrent requests
- Continuous batching

**Cons:**
- Steeper learning curve
- Primarily optimized for high-end NVIDIA GPUs
- Overkill for single-user scenarios
- More complex setup

### Comparison Summary

| Tool | Use Case | Complexity | Performance | n8n Integration |
|------|----------|------------|-------------|-----------------|
| **Ollama** | Development, single-user | Easy | Good | Native node |
| **LM Studio** | Exploration, GUI users | Easy | Good | HTTP API |
| **vLLM** | Production, multi-user | Advanced | Excellent | HTTP API |

**Recommendation for this system:** Start with **Ollama** for simplicity and native n8n integration. Graduate to vLLM only if concurrent request handling becomes a bottleneck.

---

## n8n Integration Methods

### Method 1: Native Ollama Node (Recommended)

n8n provides built-in Ollama integration through LangChain:

**Available Nodes:**
- `Ollama Model` - For text generation
- `Ollama Chat Model` - For conversational interfaces
- `Ollama Embeddings` - For vector search/RAG

**Configuration:**

```
Base URL: http://localhost:11434
Model: qwen2.5-coder:7b
```

For Docker-based n8n connecting to host Ollama:
```
Base URL: http://host.docker.internal:11434
```

For Linux Docker without Docker Desktop:
```bash
docker run --add-host=host.docker.internal:host-gateway ...
```

### Method 2: Self-Hosted AI Starter Kit

n8n provides an official Docker Compose template that bundles everything:

**Components Included:**
- n8n workflow automation
- Ollama LLM runtime
- Qdrant vector database
- PostgreSQL for n8n data

**Quick Start:**

```bash
git clone https://github.com/n8n-io/self-hosted-ai-starter-kit.git
cd self-hosted-ai-starter-kit
cp .env.example .env
# Edit .env with your settings

# For NVIDIA GPU:
docker compose --profile gpu-nvidia up
```

### Method 3: OpenAI-Compatible API

Any local LLM server with OpenAI-compatible API can connect via n8n's OpenAI node:

```javascript
// n8n OpenAI node configuration
{
  "baseURL": "http://localhost:11434/v1",
  "apiKey": "ollama",  // Any string works for local
  "model": "qwen2.5-coder:7b"
}
```

### n8n AI Agent Capabilities

The AI Agent node enables autonomous workflows:

**Features:**
- Multi-tool orchestration
- `$fromAI()` dynamic parameter generation
- Memory/conversation history
- Human-in-the-loop checkpoints

**Example Use Cases:**
- Code review automation
- Bug triage and classification
- Documentation generation
- Test case creation
- Dependency analysis

**Agent Configuration:**

```yaml
Agent Type: Tools Agent
Language Model: Ollama Chat Model
Memory: Window Buffer Memory
Tools:
  - Code Tool (custom)
  - HTTP Request
  - Database Query
```

---

## Recommended Setup for This System

Based on the hardware analysis (RTX 5070 8GB, 24GB RAM, Intel Ultra 9 285H), here is the optimal configuration:

### Primary Configuration

| Component | Setting | Rationale |
|-----------|---------|-----------|
| **LLM Server** | Ollama (native WSL2) | Lower overhead than Docker |
| **Primary Model** | qwen2.5-coder:7b-q5_k_m | Best coding at Q5 quality |
| **Backup Model** | nemotron-nano:9b-q4_k_m | For reasoning tasks |
| **Context Length** | 8192 tokens | Optimal VRAM usage (~6.5GB) |
| **Batch Size** | 512 | Good throughput |
| **GPU Layers** | All (-1) | Full GPU acceleration |

### Multi-Model Strategy

For flexibility, maintain multiple models for different tasks:

```bash
# Code generation (primary)
ollama pull qwen2.5-coder:7b

# Complex reasoning
ollama pull deepseek-r1:8b

# General + coding balance
ollama pull nemotron-nano:9b

# Fast simple tasks
ollama pull qwen2.5-coder:1.5b
```

### VRAM Allocation Strategy

```
Scenario 1: Maximum Quality
- Model: qwen2.5-coder:7b (Q5_K_M)
- Context: 8K tokens
- VRAM: ~6.5GB
- Performance: ~45 tok/s

Scenario 2: Extended Context
- Model: qwen2.5-coder:7b (Q4_K_M)
- Context: 16K tokens
- VRAM: ~7.2GB
- Performance: ~40 tok/s

Scenario 3: Complex Reasoning
- Model: deepseek-r1:8b (Q4_K_M)
- Context: 8K tokens
- VRAM: ~6GB
- Performance: ~35 tok/s (with thinking)
```

---

## Step-by-Step Installation Guide

### Prerequisites

Ensure your WSL2 environment has GPU access:

```bash
# Verify GPU visibility
nvidia-smi

# Should show: NVIDIA GeForce RTX 5070 Laptop GPU
# Driver: 581.29, CUDA Version: 12.x
```

### Step 1: Install Ollama (Native WSL2)

**Important:** Install Ollama directly in WSL2, not via Docker, for best performance and GPU access.

```bash
# Install Ollama
curl -fsSL https://ollama.com/install.sh | sh

# Verify installation
ollama --version

# Start Ollama service (if not auto-started)
ollama serve &

# Verify GPU detection
ollama run qwen2.5-coder:1.5b "Hello"
# Check output for GPU usage
```

### Step 2: Download Recommended Models

```bash
# Primary coding model
ollama pull qwen2.5-coder:7b

# Reasoning model
ollama pull deepseek-r1:8b

# Alternative for variety
ollama pull nemotron-nano:9b

# Lightweight for quick tasks
ollama pull qwen2.5-coder:1.5b

# Verify models
ollama list
```

### Step 3: Test Model Performance

```bash
# Test generation speed
time ollama run qwen2.5-coder:7b "Write a Python function to calculate fibonacci numbers" --verbose

# Check VRAM usage during inference
nvidia-smi -l 1  # Refresh every second
```

### Step 4: Configure n8n Integration

#### Option A: Existing n8n Installation

If you already have n8n running (Docker or native):

1. Open n8n web interface
2. Go to **Credentials** → **Add Credential**
3. Search for "Ollama"
4. Configure:
   - **Base URL:** `http://localhost:11434` (or `http://host.docker.internal:11434` for Docker)
5. Test connection

#### Option B: Self-Hosted AI Starter Kit (Fresh Install)

```bash
# Clone the starter kit
git clone https://github.com/n8n-io/self-hosted-ai-starter-kit.git
cd self-hosted-ai-starter-kit

# Configure environment
cp .env.example .env
nano .env

# Key settings in .env:
# OLLAMA_HOST=host.docker.internal:11434  (if using external Ollama)
# N8N_ENCRYPTION_KEY=<generate-secure-key>
# POSTGRES_PASSWORD=<secure-password>

# Start with NVIDIA GPU profile
docker compose --profile gpu-nvidia up -d

# Access n8n at http://localhost:5678
```

### Step 5: Create Test Workflow

1. Open n8n at `http://localhost:5678`
2. Create new workflow
3. Add nodes:
   - **Manual Trigger**
   - **Ollama Chat Model**
   - **Set** (for output)
4. Configure Ollama Chat Model:
   - Model: `qwen2.5-coder:7b`
   - Prompt: `Write a hello world in Python`
5. Execute and verify response

### Step 6: Create Custom Modelfile (Optional)

For optimized settings, create a custom Modelfile:

```dockerfile
# ~/ollama-models/Modelfile.coder
FROM qwen2.5-coder:7b

# Optimize for coding tasks
PARAMETER temperature 0.2
PARAMETER top_p 0.9
PARAMETER num_ctx 8192
PARAMETER num_predict 2048
PARAMETER stop "<|endoftext|>"
PARAMETER stop "<|im_end|>"

SYSTEM """You are an expert software engineer. Provide clean, well-documented code with best practices. Always explain your reasoning."""
```

```bash
# Create custom model
ollama create coder-optimized -f ~/ollama-models/Modelfile.coder

# Use in n8n
# Model: coder-optimized
```

---

## Optimal Configuration

### Ollama Modelfile Parameters

| Parameter | Recommended | Purpose |
|-----------|-------------|---------|
| `num_ctx` | 8192-16384 | Context window size |
| `num_predict` | 2048 | Max tokens to generate |
| `temperature` | 0.1-0.3 | Lower for deterministic code |
| `top_p` | 0.9 | Nucleus sampling |
| `top_k` | 40 | Top-k sampling |
| `repeat_penalty` | 1.1 | Reduce repetition |

### Environment Variables

```bash
# Add to ~/.bashrc or ~/.zshrc

# Ollama settings
export OLLAMA_HOST=127.0.0.1:11434
export OLLAMA_NUM_PARALLEL=2  # Concurrent requests
export OLLAMA_MAX_LOADED_MODELS=1  # Single model (8GB VRAM)
export OLLAMA_FLASH_ATTENTION=1  # Enable flash attention

# CUDA settings
export CUDA_VISIBLE_DEVICES=0
```

### n8n AI Node Best Practices

1. **Use Streaming** when possible for better UX
2. **Set timeouts** appropriately (code gen can take 30-60s)
3. **Implement retry logic** for robustness
4. **Cache responses** for repeated queries
5. **Monitor VRAM** to prevent OOM errors

### Workflow Optimization Tips

```javascript
// Example: Conditional model selection based on task
const task = $input.item.json.task;

let model;
if (task.includes('debug') || task.includes('explain')) {
  model = 'deepseek-r1:8b';  // Better reasoning
} else if (task.includes('quick') || task.includes('simple')) {
  model = 'qwen2.5-coder:1.5b';  // Fast response
} else {
  model = 'qwen2.5-coder:7b';  // General coding
}

return { model };
```

---

## Troubleshooting

### Issue: Ollama Not Using GPU (Blackwell)

**Symptom:** Model runs on CPU despite GPU being visible.

**Solutions:**

1. **Check Ollama version:**
   ```bash
   ollama --version
   # Ensure latest version with Blackwell fixes
   ```

2. **Verify CUDA:**
   ```bash
   nvidia-smi
   # Should show CUDA 12.x
   ```

3. **Check Ollama logs:**
   ```bash
   journalctl -u ollama -f
   # Look for GPU detection messages
   ```

4. **Force GPU:**
   ```bash
   CUDA_VISIBLE_DEVICES=0 ollama serve
   ```

5. **Monitor GitHub issue:** [#13163](https://github.com/ollama/ollama/issues/13163)

### Issue: Out of Memory (OOM)

**Symptom:** Model crashes or falls back to CPU.

**Solutions:**

1. **Reduce context length:**
   ```dockerfile
   PARAMETER num_ctx 4096
   ```

2. **Use smaller quantization:**
   ```bash
   ollama pull qwen2.5-coder:7b-q4_k_m
   ```

3. **Limit loaded models:**
   ```bash
   export OLLAMA_MAX_LOADED_MODELS=1
   ```

4. **Monitor VRAM:**
   ```bash
   watch -n 1 nvidia-smi
   ```

### Issue: Slow Performance

**Symptom:** Low tokens/second generation.

**Solutions:**

1. **Verify GPU usage:**
   ```bash
   nvidia-smi -l 1
   # GPU utilization should be high during inference
   ```

2. **Enable flash attention:**
   ```bash
   export OLLAMA_FLASH_ATTENTION=1
   ```

3. **Check for thermal throttling:**
   ```bash
   nvidia-smi -q -d TEMPERATURE
   ```

4. **Reduce context length** (KV cache impact)

### Issue: n8n Cannot Connect to Ollama

**Symptom:** Connection refused or timeout.

**Solutions:**

1. **Check Ollama is running:**
   ```bash
   curl http://localhost:11434/api/tags
   ```

2. **For Docker n8n:**
   ```
   Base URL: http://host.docker.internal:11434
   ```

3. **For Linux Docker without Desktop:**
   ```bash
   docker run --add-host=host.docker.internal:host-gateway ...
   ```

4. **Bind to all interfaces:**
   ```bash
   OLLAMA_HOST=0.0.0.0:11434 ollama serve
   ```

### Issue: WSL2 GPU Not Detected

**Symptom:** `nvidia-smi` works but Ollama doesn't see GPU.

**Solutions:**

1. **Do NOT install NVIDIA driver inside WSL2** - use Windows driver passthrough

2. **Update Windows GPU driver** to latest

3. **Restart WSL2:**
   ```powershell
   # In PowerShell (Admin)
   wsl --shutdown
   wsl
   ```

4. **Check WSL2 version:**
   ```bash
   wsl --version
   # Ensure WSL2, not WSL1
   ```

---

## Sources & References

### System Hardware & GPU
- [Best Local LLMs for 8GB VRAM 2025](https://localllm.in/blog/best-local-llms-8gb-vram-2025)
- [Best GPUs for LLM Inference 2025](https://localllm.in/blog/best-gpus-llm-inference-2025)
- [RTX 5070 for LLMs](https://www.techreviewer.com/tech-specs/nvidia-rtx-5070-gpu-for-llms/)
- [Ollama Blackwell GPU Issue](https://github.com/ollama/ollama/issues/13163)

### LLM Models
- [Qwen 2.5 Coder Technical Report](https://arxiv.org/html/2409.12186v3)
- [DeepSeek R1 GitHub](https://github.com/deepseek-ai/DeepSeek-R1)
- [NVIDIA Nemotron Nano](https://build.nvidia.com/nvidia/nvidia-nemotron-nano-9b-v2/modelcard)
- [Open Source Coding LLMs 2025](https://www.labellerr.com/blog/best-coding-llms/)

### LLM Serving
- [Ollama vs LM Studio vs vLLM Comparison](https://www.arsturn.com/blog/ollama-vs-lm-studio-vs-vllm-when-to-upgrade-your-local-llm-tool)
- [Local LLM Hosting Guide 2025](https://www.glukhov.org/post/2025/11/hosting-llms-ollama-localai-jan-lmstudio-vllm-comparison/)
- [Ollama vs vLLM Benchmarking](https://developers.redhat.com/articles/2025/08/08/ollama-vs-vllm-deep-dive-performance-benchmarking)

### n8n Integration
- [n8n Local LLM Guide](https://blog.n8n.io/local-llm/)
- [n8n Self-Hosted AI Starter Kit](https://github.com/n8n-io/self-hosted-ai-starter-kit)
- [n8n Ollama Integration](https://docs.n8n.io/integrations/builtin/cluster-nodes/sub-nodes/n8n-nodes-langchain.lmollama/)
- [n8n AI Agent Documentation](https://docs.n8n.io/integrations/builtin/cluster-nodes/root-nodes/n8n-nodes-langchain.agent/)
- [LLM Agents Guide 2025](https://blog.n8n.io/llm-agents/)

### Quantization & Optimization
- [GGUF Quantization Guide](https://enclaveai.app/blog/2025/11/12/practical-quantization-guide-iphone-mac-gguf/)
- [Ollama VRAM Requirements](https://localllm.in/blog/ollama-vram-requirements-for-local-llms)
- [Context Length and VRAM](https://localllm.in/blog/local-llm-increase-context-length-ollama)

### WSL2 & CUDA
- [NVIDIA CUDA on WSL Guide](https://docs.nvidia.com/cuda/wsl-user-guide/index.html)
- [Ubuntu WSL GPU CUDA](https://documentation.ubuntu.com/wsl/stable/howto/gpu-cuda/)
- [WSL AI Development Guide](https://www.blackmoreops.com/wsl-ai-development-setup-guide/)

---

## Appendix: Quick Reference Commands

```bash
# System Info
nvidia-smi                          # GPU status
nvidia-smi -l 1                     # Live monitoring
nvidia-smi -q -d TEMPERATURE        # Temperature check

# Ollama Management
ollama serve                        # Start server
ollama list                         # List models
ollama pull <model>                 # Download model
ollama rm <model>                   # Remove model
ollama show <model>                 # Model info
ollama run <model> "<prompt>"       # Quick test

# Model Testing
ollama run qwen2.5-coder:7b --verbose "Write hello world"
time ollama run qwen2.5-coder:7b "Explain quicksort"

# Docker (if using)
docker compose --profile gpu-nvidia up -d
docker compose logs -f
docker compose down

# n8n
# Access: http://localhost:5678
```

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-12-30 | Initial comprehensive guide |

---

*This document will be updated as new models are released and the local LLM ecosystem evolves.*
