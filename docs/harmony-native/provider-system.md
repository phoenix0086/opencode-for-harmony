# OpenCode Provider System — Comprehensive Reference

This document is a deep-dive into how the OpenCode upstream codebase defines, registers, configures, and authenticates AI providers. All file paths are relative to the OpenCode upstream source directory.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Provider Config Schema (opencode.json)](#provider-config-schema-opencodejson)
3. [How Providers Are Registered in opencode.json](#how-providers-are-registered-in-opencodejson)
4. [How API Keys Are Stored (auth.json Format)](#how-api-keys-are-stored-authjson-format)
5. [How Models Are Defined per Provider](#how-models-are-defined-per-provider)
6. [Relationship Between Provider ID, Model ID, and NPM Package](#relationship-between-provider-id-model-id-and-npm-package)
7. [The Provider Loading Pipeline](#the-provider-loading-pipeline)
8. [How to Add Custom OpenAI-Compatible Providers](#how-to-add-custom-openai-compatible-providers)
9. [Key Source Files Reference](#key-source-files-reference)

---

## Architecture Overview

The provider system spans four packages:

| Package | Role |
|---------|------|
| **`@opencode-ai/core`** | Config schema definitions (`ConfigProviderV1`), models.dev catalog fetcher, provider/model ID types, provider-options lowering |
| **`@opencode-ai/llm`** | Low-level LLM client: protocol routes (OpenAI chat, Anthropic messages, etc.), provider definitions, model factories, schema types |
| **`opencode`** (main) | Provider runtime: loads providers from config + models.dev + env + auth, resolves SDKs, manages auth storage, applies transforms |
| **AI SDK packages** | `@ai-sdk/openai`, `@ai-sdk/anthropic`, `@ai-sdk/openai-compatible`, etc. — the actual HTTP client implementations |

### Data Flow

```
models.dev API  ──>  ModelsDev service (cached JSON)
                         │
opencode.json   ──>  Config service
                         │
env variables   ──>  Env service         ──>  Provider layer  ──>  AI SDK instances
                         │                      (merges all
auth.json       ──>  Auth service              sources)
                         │
plugin hooks    ──>  Plugin service
```

---

## Provider Config Schema (opencode.json)

The provider config is defined in `packages/core/src/v1/config/provider.ts`. It is used as `Record<string, ConfigProviderV1.Info>` under the `"provider"` key in `opencode.json`.

### Top-Level Provider Config (`ConfigProviderV1.Info`)

```typescript
{
  // Base API URL for this provider (used by @ai-sdk/openai-compatible and others)
  api?: string

  // Display name for the provider
  name?: string

  // Environment variable name(s) that hold the API key
  // e.g. ["OPENAI_API_KEY"], ["ANTHROPIC_API_KEY"]
  env?: string[]

  // Provider identifier (used internally)
  id?: string

  // NPM package to use for this provider's AI SDK integration
  // e.g. "@ai-sdk/openai", "@ai-sdk/anthropic", "@ai-sdk/openai-compatible"
  npm?: string

  // Whitelist: if set, ONLY these model IDs are kept (all others removed)
  whitelist?: string[]

  // Blacklist: these model IDs are removed
  blacklist?: string[]

  // Provider-level options (passed to the AI SDK factory)
  options?: {
    apiKey?: string          // Inline API key (overrides env/auth)
    baseURL?: string         // Base URL override
    enterpriseUrl?: string   // GitHub Enterprise URL (copilot)
    setCacheKey?: boolean    // Enable promptCacheKey for this provider
    timeout?: number | false // Full request timeout (ms), false to disable
    headerTimeout?: number | false  // Header timeout (ms), false to disable
    chunkTimeout?: number    // SSE chunk timeout (ms)
    [key: string]: any       // Additional options passed to SDK factory
  }

  // Model definitions (keyed by model ID)
  models?: Record<string, ConfigProviderV1.Model>
}
```

### Model Config (`ConfigProviderV1.Model`)

```typescript
{
  // API model ID (the ID sent to the API, may differ from the key in models record)
  id?: string

  // Human-readable display name
  name?: string

  // Model family (e.g. "claude", "gpt")
  family?: string

  // Release date string (ISO format: "2025-01-15")
  release_date?: string

  // Whether this model supports file attachments
  attachment?: boolean

  // Whether this model supports reasoning/thinking mode
  reasoning?: boolean

  // Whether this model supports temperature control
  temperature?: boolean

  // Whether this model supports tool calling
  tool_call?: boolean

  // Interleaved reasoning support
  // true = standard interleaved
  // { field: "reasoning_content" | "reasoning_details" } = specific field
  interleaved?: true | { field: "reasoning_content" | "reasoning_details" }

  // Cost per million tokens
  cost?: {
    input: number
    output: number
    cache_read?: number
    cache_write?: number
    context_over_200k?: {
      input: number
      output: number
      cache_read?: number
      cache_write?: number
    }
  }

  // Token limits
  limit?: {
    context: number     // Context window size
    input?: number      // Max input tokens
    output: number      // Max output tokens
  }

  // Supported input/output modalities
  modalities?: {
    input?: ("text" | "audio" | "image" | "video" | "pdf")[]
    output?: ("text" | "audio" | "image" | "video" | "pdf")[]
  }

  // Whether the model is experimental
  experimental?: boolean

  // Model status in catalog
  status?: "alpha" | "beta" | "deprecated" | "active"

  // Override which NPM package and/or API URL this model uses
  provider?: {
    npm?: string       // NPM package override
    api?: string       // API URL override
  }

  // Model-specific options (merged with provider options, passed to SDK)
  options?: Record<string, any>

  // Model-specific HTTP headers
  headers?: Record<string, string>

  // Reasoning effort variants (e.g. "low", "medium", "high", "max")
  variants?: Record<string, {
    disabled?: boolean   // Set true to disable this variant
    [key: string]: any   // Variant-specific body parameters
  }>
}
```

---

## How Providers Are Registered in opencode.json

### Config File Locations

Config files are loaded from multiple locations, merged in this order (later overrides earlier):

1. **Global config**: `~/.config/opencode/config.json`, `opencode.json`, `opencode.jsonc`
2. **Explicit config**: `$OPENCODE_CONFIG` environment variable pointing to a file
3. **Project config**: `opencode.json` / `opencode.jsonc` in project directories (`.opencode/`, etc.)
4. **Content override**: `$OPENCODE_CONFIG_CONTENT` environment variable with inline JSON
5. **Managed config**: MDM-managed preferences on macOS
6. **Console/org config**: Fetched from account API when logged in

Source: `packages/opencode/src/config/config.ts`

### Provider Registration Example

```jsonc
// opencode.json
{
  "$schema": "https://opencode.ai/config.json",

  // Set the default model
  "model": "anthropic/claude-sonnet-4-5",

  // Small model for title generation etc.
  "small_model": "anthropic/claude-haiku-4-5",

  // Disable specific auto-loaded providers
  "disabled_providers": ["mistral"],

  // OR: Only enable specific providers (all others disabled)
  "enabled_providers": ["anthropic", "openai"],

  // Configure providers
  "provider": {
    // Override a well-known provider
    "anthropic": {
      "options": {
        "apiKey": "sk-ant-..."
      }
    },

    // Add a custom OpenAI-compatible provider
    "my-local-llm": {
      "name": "My Local LLM",
      "api": "http://localhost:11434/v1",
      "npm": "@ai-sdk/openai-compatible",
      "env": ["MY_LOCAL_API_KEY"],
      "models": {
        "llama3": {
          "name": "Llama 3",
          "limit": { "context": 8192, "output": 4096 },
          "cost": { "input": 0, "output": 0 }
        }
      }
    },

    // Configure OpenRouter with custom headers
    "openrouter": {
      "options": {
        "apiKey": "sk-or-..."
      }
    },

    // Azure with resource name
    "azure": {
      "options": {
        "resourceName": "my-azure-resource"
      }
    },

    // Amazon Bedrock with region
    "amazon-bedrock": {
      "options": {
        "region": "us-west-2",
        "profile": "my-profile"
      }
    }
  }
}
```

### Provider Source Classification

When a provider is loaded, it gets a `source` tag:

| Source | Meaning |
|--------|---------|
| `"env"` | Provider detected via environment variable (e.g., `OPENAI_API_KEY` is set) |
| `"api"` | API key found in `auth.json` |
| `"config"` | Provider configured in `opencode.json` |
| `"custom"` | Built-in provider with hardcoded custom loader logic (anthropic, openai, azure, etc.) |

---

## How API Keys Are Stored (auth.json Format)

### Storage Location

API keys are stored in `~/.local/share/opencode/auth.json` (i.e., `$XDG_DATA_HOME/opencode/auth.json`).

Source: `packages/opencode/src/auth/index.ts`

```typescript
const file = path.join(Global.Path.data, "auth.json")
// Global.Path.data = path.join(xdgData, "opencode")
// On macOS: ~/Library/Application Support/opencode/auth.json
// On Linux: ~/.local/share/opencode/auth.json
```

The file is written with `0o600` permissions (owner read/write only).

### Auth Entry Types

There are three auth entry types, discriminated by the `"type"` field:

#### 1. API Key Auth (`type: "api"`)

```json
{
  "anthropic": {
    "type": "api",
    "key": "sk-ant-...",
    "metadata": {
      "resourceName": "optional-metadata"
    }
  }
}
```

Schema:
```typescript
{
  type: "api",
  key: string,           // The API key
  metadata?: Record<string, string>  // Optional metadata (e.g., Azure resourceName,
                                      // Cloudflare accountId, etc.)
}
```

#### 2. OAuth Auth (`type: "oauth"`)

```json
{
  "github-copilot": {
    "type": "oauth",
    "refresh": "gho_...",
    "access": "gho_...",
    "expires": 1700000000,
    "accountId": "optional-account-id",
    "enterpriseUrl": "https://github.example.com"
  }
}
```

Schema:
```typescript
{
  type: "oauth",
  refresh: string,       // Refresh token
  access: string,        // Access token
  expires: number,       // Expiration timestamp (non-negative integer)
  accountId?: string,
  enterpriseUrl?: string
}
```

#### 3. Well-Known Auth (`type: "wellknown"`)

Used for remote config endpoints that serve an `/.well-known/opencode` file:

```json
{
  "https://my-opencode-server.com": {
    "type": "wellknown",
    "key": "env-var-name",
    "token": "bearer-token"
  }
}
```

### Full auth.json Example

```json
{
  "anthropic": {
    "type": "api",
    "key": "sk-ant-api03-..."
  },
  "openai": {
    "type": "api",
    "key": "sk-proj-..."
  },
  "github-copilot": {
    "type": "oauth",
    "refresh": "gho_...",
    "access": "gho_...",
    "expires": 1700000000
  },
  "amazon-bedrock": {
    "type": "api",
    "key": "bearer-token-for-bedrock"
  },
  "cloudflare-ai-gateway": {
    "type": "api",
    "key": "cf-api-token",
    "metadata": {
      "accountId": "abc123",
      "gatewayId": "my-gateway"
    }
  }
}
```

### API Key Resolution Order

When the provider system needs an API key, it checks in this order:

1. **`provider.options.apiKey`** in `opencode.json` (highest priority)
2. **Environment variables** listed in `provider.env` (e.g., `OPENAI_API_KEY`)
3. **`auth.json`** entry for the provider ID
4. **Custom loader logic** (e.g., Bedrock credential chain, Google ADC, etc.)

---

## How Models Are Defined per Provider

### The models.dev Catalog

OpenCode fetches a centralized model catalog from `https://models.dev/api.json` every 60 minutes. This is cached at `~/.cache/opencode/models.json`.

Source: `packages/core/src/models-dev.ts`

The catalog schema (`ModelsDev.Provider`):

```typescript
{
  id: string          // Provider ID (e.g. "anthropic")
  name: string        // Display name
  env: string[]       // Env var names for API key
  api?: string        // Default API URL
  npm?: string        // Default NPM package
  models: Record<string, {
    id: string
    name: string
    family?: string
    release_date: string
    attachment: boolean
    reasoning: boolean
    temperature: boolean
    tool_call: boolean
    interleaved?: true | { field: "reasoning_content" | "reasoning_details" }
    cost?: { input, output, cache_read?, cache_write?, tiers?, context_over_200k? }
    limit: { context, input?, output }
    modalities?: { input: Modality[], output: Modality[] }
    experimental?: { modes?: Record<string, { cost?, provider? }> }
    status?: "alpha" | "beta" | "deprecated"
    provider?: { npm?, api? }
  }>
}
```

### Model Conversion to Internal Format

Each `ModelsDev.Model` is converted to the internal `Provider.Model` type by `fromModelsDevModel()` in `packages/opencode/src/provider/provider.ts`:

```typescript
Model = {
  id: ModelV2.ID,           // Internal model ID
  providerID: ProviderV2.ID, // Parent provider ID
  name: string,              // Display name
  family?: string,           // Model family
  api: {
    id: string,              // ID sent to the API
    url: string,             // API base URL
    npm: string,             // NPM package for SDK
  },
  status: "alpha" | "beta" | "deprecated" | "active",
  headers: Record<string, string>,
  options: Record<string, any>,
  cost: {
    input: number,
    output: number,
    cache: { read: number, write: number },
    tiers?: [...],
    experimentalOver200K?: { input, output, cache },
  },
  limit: {
    context: number,
    input?: number,
    output: number,
  },
  capabilities: {
    temperature: boolean,
    reasoning: boolean,
    attachment: boolean,
    toolcall: boolean,
    input: { text, audio, image, video, pdf },
    output: { text, audio, image, video, pdf },
    interleaved: boolean | { field: "reasoning_content" | "reasoning_details" },
  },
  release_date: string,
  variants: Record<string, Record<string, any>>,
}
```

### Model Variants (Reasoning Effort Tiers)

Variants are generated by `ProviderTransform.variants()` in `packages/opencode/src/provider/transform.ts`. They map reasoning effort levels to provider-specific API parameters:

- **OpenAI**: `{ reasoningEffort: "low" | "medium" | "high" | "xhigh" }`
- **Anthropic**: `{ thinking: { type: "enabled", budgetTokens: 16000 } }` or adaptive `{ thinking: { type: "adaptive" }, effort: "high" }`
- **Google**: `{ thinkingConfig: { includeThoughts: true, thinkingBudget: 16000 } }`
- **Bedrock**: `{ reasoningConfig: { type: "enabled", budgetTokens: 16000 } }`
- **OpenAI-compatible**: `{ reasoningEffort: "low" | "medium" | "high" }`

---

## Relationship Between Provider ID, Model ID, and NPM Package

### Provider ID

A branded string type (`ProviderV2.ID`). Well-known providers have static constants:

```typescript
ProviderV2.ID.opencode       // "opencode"
ProviderV2.ID.anthropic      // "anthropic"
ProviderV2.ID.openai         // "openai"
ProviderV2.ID.google         // "google"
ProviderV2.ID.googleVertex    // "google-vertex"
ProviderV2.ID.githubCopilot  // "github-copilot"
ProviderV2.ID.amazonBedrock  // "amazon-bedrock"
ProviderV2.ID.azure          // "azure"
ProviderV2.ID.openrouter     // "openrouter"
ProviderV2.ID.mistral        // "mistral"
ProviderV2.ID.gitlab         // "gitlab"
```

Source: `packages/core/src/provider.ts`

### Model ID

A branded string type (`ModelV2.ID`). The full model reference is `providerID/modelID` (e.g., `"anthropic/claude-sonnet-4-5"`).

### NPM Package (`api.npm`)

Determines which AI SDK package is used to make the HTTP request. The bundled providers map in `packages/opencode/src/provider/provider.ts` lists all pre-installed packages:

| NPM Package | Factory Function | Used For |
|-------------|-----------------|----------|
| `@ai-sdk/openai` | `createOpenAI` | OpenAI |
| `@ai-sdk/anthropic` | `createAnthropic` | Anthropic |
| `@ai-sdk/google` | `createGoogleGenerativeAI` | Google (Gemini) |
| `@ai-sdk/google-vertex` | `createVertex` | Google Vertex AI |
| `@ai-sdk/google-vertex/anthropic` | `createVertexAnthropic` | Anthropic via Vertex |
| `@ai-sdk/azure` | `createAzure` | Azure OpenAI |
| `@ai-sdk/amazon-bedrock` | `createAmazonBedrock` | AWS Bedrock |
| `@ai-sdk/amazon-bedrock/mantle` | `createBedrockMantle` | Bedrock Mantle models |
| `@ai-sdk/openai-compatible` | `createOpenAICompatible` | **Default for custom providers** |
| `@ai-sdk/openrouter` (via `@openrouter/ai-sdk-provider`) | `createOpenRouter` | OpenRouter |
| `@ai-sdk/xai` | `createXai` | xAI (Grok) |
| `@ai-sdk/mistral` | `createMistral` | Mistral |
| `@ai-sdk/groq` | `createGroq` | Groq |
| `@ai-sdk/deepinfra` | `createDeepInfra` | DeepInfra |
| `@ai-sdk/cerebras` | `createCerebras` | Cerebras |
| `@ai-sdk/cohere` | `createCohere` | Cohere |
| `@ai-sdk/gateway` | `createGateway` | AI SDK Gateway |
| `@ai-sdk/togetherai` | `createTogetherAI` | Together AI |
| `@ai-sdk/perplexity` | `createPerplexity` | Perplexity |
| `@ai-sdk/vercel` | `createVercel` | Vercel AI |
| `@ai-sdk/alibaba` | `createAlibaba` | Alibaba (Qwen) |
| `gitlab-ai-provider` | `createGitLab` | GitLab Duo |
| `venice-ai-sdk-provider` | `createVenice` | Venice AI |

### Resolution Logic for NPM Package

When a model is loaded, its `api.npm` is determined by this precedence:

```
model.provider.npm  (per-model override in config)
  ?? provider.npm    (provider-level in config)
  ?? existingModel.api.npm  (from models.dev)
  ?? modelsDev[providerID].npm  (from models.dev provider)
  ?? "@ai-sdk/openai-compatible"  (FALLBACK DEFAULT)
```

Source: `packages/opencode/src/provider/provider.ts` lines ~1398-1403

### SDK Resolution at Runtime

When actually creating an SDK instance (`resolveSDK` function):

1. Check if the NPM package is in `BUNDLED_PROVIDERS` (pre-installed)
2. If not bundled, try `Npm.add(model.api.npm)` to dynamically install it
3. If the npm value starts with `file://`, load as a local path
4. Find the factory function by looking for an export starting with `"create"`
5. Call `factory({ name: providerID, ...options })` to get the SDK instance
6. SDKs are cached by hash of `{ providerID, npm, options }` to avoid re-creation

---

## The Provider Loading Pipeline

The full loading sequence in `packages/opencode/src/provider/provider.ts` (layer initialization):

### Step 1: Load models.dev Catalog
```
catalog = mapValues(modelsDev, fromModelsDevProvider)
database = mapValues(catalog, toPublicInfo)
```
All known providers and their models are loaded from the models.dev JSON.

### Step 2: Load Plugin Models
Plugins with a `provider.models` hook can modify the model list for any provider.

### Step 3: Extend Database from Config
For each provider in `opencode.json`'s `provider` key:
- Merge with existing database entry (or create new)
- Process model definitions, applying overrides
- Set `source: "config"`

### Step 4: Load Environment Variables
For each provider in the database:
- Check if any of its `env` variables are set
- If found, set `source: "env"` and store the key

### Step 5: Load Auth Keys
For each entry in `auth.json`:
- If `type === "api"`, merge into provider with `source: "api"`

### Step 6: Plugin Auth Loaders
Plugins with `auth.loader` hooks can provide additional options.

### Step 7: Custom Loaders
Built-in providers have hardcoded `custom()` loader functions that:
- Set provider-specific headers (e.g., Anthropic beta headers)
- Configure custom `getModel` functions (e.g., OpenAI uses `sdk.responses()`)
- Handle special auth flows (e.g., Bedrock credential chain, Google ADC)
- Return `autoload: true/false` to control whether provider loads without explicit config

### Step 8: Re-apply Config
Config providers are re-applied to pick up any modifications from custom loaders.

### Step 9: Filter and Validate
- Remove disabled providers (`disabled_providers`)
- Remove providers not in `enabled_providers` (if set)
- Remove deprecated and alpha models (unless experimental enabled)
- Apply whitelist/blacklist filtering
- Remove providers with zero models

---

## How to Add Custom OpenAI-Compatible Providers

### Method 1: Via opencode.json (Recommended)

The simplest way to add any OpenAI-compatible provider:

```jsonc
{
  "provider": {
    "my-provider": {
      "name": "My Custom Provider",
      "api": "https://api.my-provider.com/v1",
      "npm": "@ai-sdk/openai-compatible",
      "env": ["MY_PROVIDER_API_KEY"],
      "models": {
        "my-model-v1": {
          "name": "My Model V1",
          "limit": { "context": 128000, "output": 8192 },
          "cost": { "input": 0.5, "output": 1.5 },
          "reasoning": true,
          "attachment": false,
          "temperature": true,
          "modalities": {
            "input": ["text", "image"],
            "output": ["text"]
          }
        },
        "my-model-v2": {
          "name": "My Model V2",
          "limit": { "context": 32000, "output": 4096 },
          "cost": { "input": 0, "output": 0 }
        }
      }
    }
  }
}
```

Key points:
- **`npm`** defaults to `"@ai-sdk/openai-compatible"` if omitted
- **`api`** sets the base URL for all models under this provider
- **`env`** specifies which environment variable holds the API key
- Each model's `provider.api` and `provider.npm` can override the provider-level values
- Models inherit defaults from the provider and from models.dev (if the provider ID matches)

### Method 2: With API Key in Config

```jsonc
{
  "provider": {
    "ollama": {
      "name": "Ollama (Local)",
      "api": "http://localhost:11434/v1",
      "options": {
        "apiKey": "ollama"  // Ollama doesn't need a real key but SDK requires one
      },
      "models": {
        "llama3.1:70b": {
          "name": "Llama 3.1 70B",
          "limit": { "context": 128000, "output": 4096 },
          "cost": { "input": 0, "output": 0 }
        }
      }
    }
  }
}
```

### Method 3: With Per-Model NPM Overrides

Different models under the same provider can use different SDK packages:

```jsonc
{
  "provider": {
    "my-multi-provider": {
      "name": "Multi Provider",
      "models": {
        "openai-model": {
          "provider": { "npm": "@ai-sdk/openai", "api": "https://api.openai.com/v1" },
          "limit": { "context": 128000, "output": 16384 }
        },
        "compatible-model": {
          "provider": { "npm": "@ai-sdk/openai-compatible", "api": "https://other.api/v1" },
          "limit": { "context": 32000, "output": 4096 }
        }
      }
    }
  }
}
```

### Method 4: Via Plugin

Plugins can register entirely new providers or modify existing ones. A plugin with `auth` and `provider` hooks:

```typescript
// plugin.ts
import { definePlugin } from "@opencode-ai/plugin"

export default definePlugin({
  name: "my-plugin",
  auth: {
    provider: "my-provider",
    methods: [{ type: "api", label: "API Key" }],
    loader: async (getAuth, provider) => {
      const auth = await getAuth()
      return { baseURL: "https://my-api.com/v1" }
    },
  },
  provider: {
    id: "my-provider",
    models: async (provider, { auth }) => {
      return {
        "my-model": { /* model definition */ },
      }
    },
  },
})
```

### How @ai-sdk/openai-compatible Is Used

`@ai-sdk/openai-compatible` is the **default fallback NPM package** for any provider not in the bundled providers list. It provides a generic OpenAI-compatible client that:

1. Accepts `{ name, baseURL, apiKey, headers, ... }` options
2. Uses `createOpenAICompatible()` factory
3. Supports `languageModel(id)`, `chat(id)`, `responses(id)` methods
4. Handles standard OpenAI chat completions API format
5. Includes `includeUsage: true` by default (set in `resolveSDK`)
6. Supports `cache_control: { type: "ephemeral" }` for prompt caching

The `provider-options.ts` lowering for `@ai-sdk/openai-compatible`:
- Passes `baseURL` as the URL
- Converts `reasoningEffort` to `reasoning_effort` (snake_case)
- Passes all other options as-is

### Interleaved Reasoning for OpenAI-Compatible Providers

For OpenAI-compatible providers with DeepSeek-style models, the system auto-detects interleaved reasoning:

```typescript
// If the model ID contains "deepseek" and no existing interleaved config:
interleaved: { field: "reasoning_content" }
```

This enables the `reasoning_content` field to be preserved across multi-turn conversations.

---

## Key Source Files Reference

| File | Purpose |
|------|---------|
| `packages/core/src/v1/config/provider.ts` | Config schema for provider and model definitions in `opencode.json` |
| `packages/core/src/v1/config/provider-options.ts` | Provider options lowering (SDK-specific option transformation) |
| `packages/core/src/v1/config/config.ts` | Top-level config schema (`Info` with `provider`, `model`, `disabled_providers`, etc.) |
| `packages/core/src/provider.ts` | `ProviderV2.ID` branded type with well-known provider constants |
| `packages/core/src/model.ts` | `ModelV2.ID`, `ModelV2.Info` types, model reference parsing |
| `packages/core/src/models-dev.ts` | models.dev catalog fetcher and cache management |
| `packages/core/src/global.ts` | Global path definitions (data, config, cache, state) |
| `packages/opencode/src/provider/provider.ts` | Main provider runtime: loading, merging, SDK resolution, language model creation |
| `packages/opencode/src/provider/transform.ts` | Model transforms: message normalization, reasoning variants, provider options, schema fixes |
| `packages/opencode/src/provider/auth.ts` | Provider auth service: OAuth flows, API key prompts, auth method definitions |
| `packages/opencode/src/provider/model-status.ts` | Model status enum (`alpha`, `beta`, `deprecated`, `active`) |
| `packages/opencode/src/provider/error.ts` | Provider error parsing (context overflow, API errors, timeout handling) |
| `packages/opencode/src/auth/index.ts` | Auth storage service: read/write `auth.json` with `api`, `oauth`, `wellknown` types |
| `packages/opencode/src/config/config.ts` | Config loading service: file discovery, merging, remote config, plugin integration |
| `packages/opencode/src/server/auth.ts` | Server authentication (HTTP basic auth for `opencode serve`) |
| `packages/llm/src/provider.ts` | LLM provider definition type (`Definition`, `ModelFactory`) |
| `packages/llm/src/providers/index.ts` | Re-exports all built-in LLM provider modules |
| `packages/llm/src/providers/openai-compatible.ts` | OpenAI-compatible provider: `configure()`, profile-based presets |
| `packages/llm/src/providers/openai-compatible-profile.ts` | Named profiles (baseten, cerebras, deepseek, fireworks, groq, etc.) |
| `packages/llm/src/providers/openai.ts` | OpenAI provider: Responses API, Chat API, WebSocket routes |
| `packages/llm/src/providers/anthropic.ts` | Anthropic provider: Messages API with x-api-key auth |
| `packages/llm/src/schema/ids.ts` | Core ID types: `ProviderID`, `ModelID`, `ReasoningEffort`, etc. |
| `packages/llm/src/llm.ts` | LLM request/response API surface |
