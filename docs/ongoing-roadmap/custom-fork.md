# Custom n8n Fork Research

> **Status**: Research Complete
> **Date**: 2025-12-28
> **Purpose**: Document what it takes to create a fully custom fork of n8n while preserving all features

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Licensing Implications](#licensing-implications)
3. [n8n Source Architecture](#n8n-source-architecture)
4. [Branding Customization Points](#branding-customization-points)
5. [Building Your Fork](#building-your-fork)
6. [Docker Image Build Pipeline](#docker-image-build-pipeline)
7. [Upstream Sync Strategy](#upstream-sync-strategy)
8. [Complete Fork Checklist](#complete-fork-checklist)
9. [Real-World Fork Examples](#real-world-fork-examples)
10. [Effort Estimates](#effort-estimates)
11. [Risks and Mitigations](#risks-and-mitigations)
12. [Integration with Current Deployment](#integration-with-current-deployment)
13. [Sources](#sources)

---

## Executive Summary

Creating a fully custom fork of n8n while preserving all features is **possible but comes with significant licensing constraints and ongoing maintenance burden**.

### Key Findings

| Aspect | Assessment |
|--------|------------|
| **Feasibility** | Technically feasible |
| **Licensing** | Restrictive (Sustainable Use License, not OSI-approved open source) |
| **Commercial Use** | Internal only; commercial distribution prohibited without license |
| **Enterprise Features** | Require separate licensing (.ee. files excluded from SUL) |
| **Maintenance Burden** | 2-4 hours/week for upstream sync |
| **Initial Setup** | 1-2 weeks for complete fork with CI/CD |

### Decision Matrix

| Use Case | Recommendation |
|----------|----------------|
| Internal workflow automation | Fork is viable |
| White-label for internal teams | Fork is viable |
| Sell as SaaS product | Contact n8n for commercial license |
| Offer as managed service | Contact n8n for commercial license |
| Contribute features upstream | Fork + PR strategy |

---

## Licensing Implications

### Sustainable Use License Overview

n8n uses the **Sustainable Use License (Version 1.0)**, which is classified as "fair-code" but is **NOT OSI-approved open source**.

**License Source**: https://github.com/n8n-io/n8n/blob/master/LICENSE.md

### What's Allowed

| Permission | Details |
|------------|---------|
| Internal business use | Use within your organization for any purpose |
| Personal use | Individual, non-commercial usage |
| Modification | Change code for your own purposes |
| Derivative works | Create modified versions (subject to limitations) |
| Free redistribution | Share for non-commercial purposes only |

### What's Prohibited

| Restriction | Details |
|-------------|---------|
| Commercial distribution | Cannot sell or charge for the software |
| Competing products | Cannot offer as competing SaaS/service |
| License removal | Cannot obscure or remove license notices |
| Enterprise bypass | Cannot use .ee. files without enterprise license |

### Enterprise Features (.ee. Files)

Files containing `.ee.` in their filename or directory path are **NOT covered** by the Sustainable Use License. These require a separate **n8n Enterprise License**.

**Enterprise-only features include:**

| Feature | Location |
|---------|----------|
| SSO (SAML) | `packages/cli/src/sso/*.ee.ts` |
| SSO (LDAP) | `packages/cli/src/ldap/*.ee.ts` |
| Workflow sharing | `packages/cli/src/workflows/*.ee.ts` |
| Credential sharing | `packages/cli/src/credentials/*.ee.ts` |
| Version control (Git) | `packages/cli/src/environments/*.ee.ts` |
| Audit logs | `packages/cli/src/audit/*.ee.ts` |
| Log streaming | `packages/cli/src/logging/*.ee.ts` |
| External secrets | `packages/cli/src/external-secrets/*.ee.ts` |
| Multi-main mode | `packages/cli/src/scaling/*.ee.ts` |
| Projects | `packages/cli/src/projects/*.ee.ts` |
| External binary storage | Various `.ee.` files |

### Options for Enterprise Features

1. **Exclude .ee. files**: Fork without enterprise features (simplest)
2. **License from n8n**: Contact n8n for commercial/enterprise license
3. **Build replacements**: Create your own implementations (significant effort)
4. **Hybrid approach**: Use community features, license specific enterprise needs

### Legal Recommendations

- Consult with legal counsel before commercial deployment
- Document your use case and ensure compliance
- Keep records of how the fork is used internally
- Do not distribute commercially without proper licensing

---

## n8n Source Architecture

### Monorepo Overview

n8n is organized as a **pnpm 10.18.3 monorepo** using **Turborepo 2.5.4** for task orchestration.

**Repository**: https://github.com/n8n-io/n8n

### Package Structure

```
n8n/
├── packages/
│   ├── cli/                        # Main entry point
│   │   ├── src/
│   │   │   ├── commands/           # Start, Worker, Webhook commands
│   │   │   ├── controllers/        # REST API controllers
│   │   │   ├── databases/          # Database migrations & entities
│   │   │   ├── services/           # Business logic services
│   │   │   ├── workflows/          # Workflow management
│   │   │   ├── credentials/        # Credential management
│   │   │   ├── executions/         # Execution handling
│   │   │   └── *.ee.*/             # Enterprise features (excluded)
│   │   └── package.json
│   │
│   ├── core/                       # Workflow execution engine
│   │   ├── src/
│   │   │   ├── execution/          # Execution logic
│   │   │   ├── node-execution/     # Node runners
│   │   │   └── webhooks/           # Webhook handling
│   │   └── package.json
│   │   # ⚠️ Contact n8n team before modifying
│   │
│   ├── workflow/                   # Shared interfaces
│   │   ├── src/
│   │   │   ├── Interfaces.ts       # Core type definitions
│   │   │   ├── Workflow.ts         # Workflow class
│   │   │   └── NodeTypes.ts        # Node type system
│   │   └── package.json
│   │
│   ├── nodes-base/                 # Built-in integrations (400+)
│   │   ├── nodes/                  # Node implementations
│   │   ├── credentials/            # Credential types
│   │   └── package.json
│   │
│   ├── node-dev/                   # CLI for custom nodes
│   │   └── package.json
│   │
│   ├── @n8n/                       # Scoped packages
│   │   ├── config/                 # Configuration management
│   │   ├── db/                     # Database abstraction
│   │   ├── api-types/              # API type definitions
│   │   ├── client-oauth2/          # OAuth2 client
│   │   ├── codemirror-lang-sql/    # SQL editor support
│   │   ├── di/                     # Dependency injection
│   │   ├── permissions/            # Permission system
│   │   ├── stores/                 # Pinia state stores
│   │   ├── task-runner/            # Task runner package
│   │   └── typeorm/                # TypeORM customizations
│   │
│   ├── frontend/                   # Frontend packages
│   │   ├── @n8n/
│   │   │   ├── design-system/      # Vue components + Storybook
│   │   │   │   ├── src/
│   │   │   │   │   ├── components/ # Reusable UI components
│   │   │   │   │   ├── css/        # Tokens, themes, styles
│   │   │   │   │   └── composables/# Vue composables
│   │   │   │   └── package.json
│   │   │   │
│   │   │   └── i18n/               # Internationalization
│   │   │       ├── src/locales/    # Translation files
│   │   │       │   └── en.json     # English strings
│   │   │       └── package.json
│   │   │
│   │   └── editor-ui/              # Main frontend application
│   │       ├── public/             # Static assets (logos, favicons)
│   │       ├── src/
│   │       │   ├── components/     # Vue components
│   │       │   ├── views/          # Page views
│   │       │   ├── stores/         # Pinia stores
│   │       │   ├── composables/    # Vue composables
│   │       │   └── plugins/        # Vue plugins
│   │       ├── index.html          # Entry HTML
│   │       └── package.json
│   │
│   ├── extensions/                 # Extension packages
│   │
│   └── testing/                    # Testing utilities
│
├── docker/                         # Docker configurations
│   ├── images/
│   │   └── n8n/
│   │       └── Dockerfile          # Main Docker image
│   └── compose/                    # Docker Compose examples
│
├── .github/                        # GitHub configurations
│   ├── workflows/                  # CI/CD pipelines
│   │   ├── docker-build-push.yml   # Docker image builds
│   │   ├── test.yml                # Test pipeline
│   │   └── release.yml             # Release pipeline
│   └── scripts/                    # Build scripts
│
├── pnpm-workspace.yaml             # Workspace definition
├── turbo.json                      # Turborepo configuration
├── package.json                    # Root package.json
└── LICENSE.md                      # Sustainable Use License
```

### Package Dependencies

```
┌─────────────────────────────────────────────────────────────┐
│                        CLI (entry point)                     │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │    Core     │  │  Workflow   │  │    nodes-base       │  │
│  │  (engine)   │  │ (interfaces)│  │   (400+ nodes)      │  │
│  └──────┬──────┘  └──────┬──────┘  └──────────┬──────────┘  │
│         │                │                     │             │
│         └────────────────┴─────────────────────┘             │
│                          │                                   │
│              ┌───────────┴───────────┐                       │
│              │      @n8n/*           │                       │
│              │  (scoped packages)    │                       │
│              └───────────────────────┘                       │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                     Frontend (editor-ui)                     │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌──────────────┐  ┌────────────────┐  │
│  │  design-system  │  │     i18n     │  │    stores      │  │
│  │   (Vue + CSS)   │  │ (translations)│  │   (Pinia)      │  │
│  └─────────────────┘  └──────────────┘  └────────────────┘  │
│                           │                                  │
│              ┌────────────┴────────────┐                     │
│              │        workflow         │                     │
│              │   (shared interfaces)   │                     │
│              └─────────────────────────┘                     │
└─────────────────────────────────────────────────────────────┘
```

### Build System Requirements

| Requirement | Minimum Version | Notes |
|-------------|-----------------|-------|
| Node.js | 22.16+ | LTS recommended |
| pnpm | 10.2+ | Use corepack |
| Python | 3.x | For native modules |
| GCC/G++ | Latest | Build tools |
| Make | Latest | Build tools |

**Platform-specific dependencies:**

```bash
# Debian/Ubuntu
apt-get install -y build-essential python3

# CentOS/RHEL
yum install gcc gcc-c++ make python3

# macOS
# Xcode Command Line Tools (usually pre-installed)

# Windows
npm add -g windows-build-tools
```

---

## Branding Customization Points

### Overview

White-labeling n8n requires modifying two main packages:
1. `packages/frontend/@n8n/design-system` - CSS and Vue components
2. `packages/frontend/editor-ui` - Main frontend application

**Official Documentation**: https://docs.n8n.io/embed/white-labelling/

### 1. Theme Colors

**Files to modify:**

```
packages/frontend/@n8n/design-system/src/css/_tokens.scss      # Light theme
packages/frontend/@n8n/design-system/src/css/_tokens.dark.scss # Dark theme
```

**Primary color variables:**

```scss
// _tokens.scss
:root {
  // Primary brand color (HSL format)
  --color-primary-h: 204;        // Hue (0-360)
  --color-primary-s: 100%;       // Saturation
  --color-primary-l: 50%;        // Lightness

  // Derived primary shades
  --color-primary: hsl(var(--color-primary-h), var(--color-primary-s), var(--color-primary-l));
  --color-primary-tint-1: hsl(var(--color-primary-h), var(--color-primary-s), 60%);
  --color-primary-tint-2: hsl(var(--color-primary-h), var(--color-primary-s), 70%);
  --color-primary-shade-1: hsl(var(--color-primary-h), var(--color-primary-s), 40%);

  // Background colors
  --color-background-base: #ffffff;
  --color-background-light: #f5f5f5;
  --color-background-dark: #e0e0e0;

  // Text colors
  --color-text-base: #333333;
  --color-text-light: #666666;
  --color-text-dark: #000000;

  // Accent colors
  --color-success: #10b981;
  --color-warning: #f59e0b;
  --color-danger: #ef4444;
}
```

**Color conversion helper:**

| Format | Example |
|--------|---------|
| Hex | `#0099ff` |
| HSL | `hue: 204, saturation: 100%, lightness: 50%` |

### 2. Logo Assets

**Directory:** `packages/frontend/editor-ui/public/`

| File | Dimensions | Purpose |
|------|------------|---------|
| `favicon-16x16.png` | 16x16 px | Browser tab icon (small) |
| `favicon-32x32.png` | 32x32 px | Browser tab icon (large) |
| `favicon.ico` | Multi-size | Legacy favicon |
| `n8n-logo.svg` | Variable | General logo usage |
| `n8n-logo-collapsed.svg` | ~40x40 px | Sidebar collapsed state |
| `n8n-logo-expanded.svg` | ~120x40 px | Sidebar expanded state |

**Logo usage in components:**

```
packages/frontend/editor-ui/src/components/MainSidebar.vue  # Sidebar logo
packages/frontend/editor-ui/src/components/Logo.vue         # Reusable logo component
```

**MainSidebar.vue customization:**

```vue
<template>
  <div class="sidebar-logo">
    <img
      v-if="sidebarCollapsed"
      src="/your-logo-collapsed.svg"
      alt="Your Brand"
    />
    <img
      v-else
      src="/your-logo-expanded.svg"
      alt="Your Brand"
    />
  </div>
</template>

<style scoped>
.sidebar-logo img {
  max-height: 40px;
  /* Adjust sizing as needed */
}
</style>
```

### 3. Text and Brand Name

**Primary file:** `packages/frontend/@n8n/i18n/src/locales/en.json`

**Key strings to replace:**

```json
{
  "_brand": {
    "name": "Your Brand Name",
    "tagline": "Your Tagline",
    "website": "https://yourdomain.com"
  },
  "about.aboutN8n": "About Your Brand",
  "mainSidebar.workflows": "Workflows",
  "generic.workflow": "Workflow",
  "settings.n8nApi": "Your Brand API"
}
```

**Using Vue I18n linked messages:**

```json
{
  "_brand.name": "YourBrand",
  "about.aboutN8n": "About @:_brand.name"
}
```

### 4. Window/Page Title

**Files to modify:**

```
packages/frontend/editor-ui/index.html
packages/frontend/editor-ui/src/composables/useDocumentTitle.ts
```

**index.html:**

```html
<!DOCTYPE html>
<html>
  <head>
    <title>Your Brand - Workflow Automation</title>
    <!-- ... -->
  </head>
</html>
```

**useDocumentTitle.ts:**

```typescript
const DEFAULT_TITLE = 'Your Brand';
const DEFAULT_TAGLINE = 'Workflow Automation';

export function useDocumentTitle() {
  const setTitle = (title?: string) => {
    document.title = title
      ? `${title} | ${DEFAULT_TITLE}`
      : `${DEFAULT_TITLE} - ${DEFAULT_TAGLINE}`;
  };

  return { setTitle };
}
```

### 5. Additional Customization Points

**Email templates:**
```
packages/cli/src/emails/templates/
```

**Public documentation links:**
```
packages/frontend/editor-ui/src/constants.ts
```

**Error pages:**
```
packages/frontend/editor-ui/src/views/ErrorView.vue
```

**Loading screens:**
```
packages/frontend/editor-ui/src/components/LoadingScreen.vue
```

---

## Building Your Fork

### Initial Setup

```bash
# 1. Fork the repository on GitHub
# Navigate to https://github.com/n8n-io/n8n
# Click "Fork" button

# 2. Clone your fork
git clone https://github.com/YOUR-ORG/n8n.git
cd n8n

# 3. Add upstream remote for syncing
git remote add upstream https://github.com/n8n-io/n8n.git

# 4. Verify remotes
git remote -v
# origin    https://github.com/YOUR-ORG/n8n.git (fetch)
# origin    https://github.com/YOUR-ORG/n8n.git (push)
# upstream  https://github.com/n8n-io/n8n.git (fetch)
# upstream  https://github.com/n8n-io/n8n.git (push)

# 5. Enable corepack for pnpm
corepack enable
corepack prepare --activate

# 6. Install all dependencies
pnpm install

# 7. Build all packages
pnpm build

# 8. Verify build succeeded
pnpm start
# Open http://localhost:5678
```

### Development Commands

| Command | Purpose |
|---------|---------|
| `pnpm install` | Install dependencies, link packages |
| `pnpm build` | Build all packages for production |
| `pnpm dev` | Development mode with hot reload |
| `pnpm dev:be` | Backend-only development |
| `pnpm dev:fe` | Frontend-only development |
| `pnpm dev:ai` | AI/LangChain nodes development |
| `pnpm test` | Run all tests |
| `pnpm test:unit` | Run unit tests only |
| `pnpm test:e2e` | Run end-to-end tests |
| `pnpm lint` | Run linting |
| `pnpm lint:fix` | Fix linting issues |
| `pnpm start` | Run in production mode |
| `pnpm typecheck` | Run TypeScript type checking |

### Development Workflow

```bash
# Terminal 1: Full development mode
pnpm dev

# Alternative: Resource-constrained development
# Terminal 1: Backend only
pnpm dev:be

# Terminal 2: Frontend only
pnpm dev:fe

# Enable hot reload for custom nodes
N8N_DEV_RELOAD=true pnpm dev
```

### Creating a Customizations Branch

```bash
# Create a branch for your customizations
git checkout -b customizations

# Make branding changes
# ... edit files ...

# Commit with clear messages
git add -A
git commit -m "brand: Replace logos with custom branding"
git commit -m "brand: Update color scheme to match brand"
git commit -m "brand: Replace n8n references with brand name"

# Push to your fork
git push -u origin customizations
```

---

## Docker Image Build Pipeline

### Official Dockerfile Structure

**Location:** `docker/images/n8n/Dockerfile`

```dockerfile
# Stage 1: System dependencies
FROM n8nio/base:${NODE_VERSION} AS system-deps
# Base image includes Node.js + system packages

# Stage 2: Runtime image
FROM system-deps AS runtime

# Set production environment
ENV NODE_ENV=production
ENV ICU_DATA=/usr/local/lib/node_modules/full-icu

# Set working directory
WORKDIR /home/node

# Copy pre-compiled n8n (from CI build artifacts)
COPY ./compiled /usr/local/lib/node_modules/n8n

# Install entrypoint script
COPY docker/images/n8n/docker-entrypoint.sh /docker-entrypoint.sh

# Upgrade npm and rebuild native modules
RUN npm install -g npm@11.6.4 && \
    cd /usr/local/lib/node_modules/n8n && \
    npm rebuild sqlite3

# Create symlink for n8n command
RUN ln -s /usr/local/lib/node_modules/n8n/bin/n8n /usr/local/bin/n8n

# Create data directory
RUN mkdir -p /home/node/.n8n && \
    chown -R node:node /home/node/.n8n

# Expose port
EXPOSE 5678

# Run as non-root user
USER node

# Use tini as init
ENTRYPOINT ["tini", "--", "/docker-entrypoint.sh"]
```

### Custom Fork Docker Build

**Complete GitHub Actions workflow:**

```yaml
# .github/workflows/docker-build.yml
name: Build Custom n8n Docker Image

on:
  push:
    branches: [main, customizations]
    tags: ['v*']
  pull_request:
    branches: [main]
  workflow_dispatch:
    inputs:
      version:
        description: 'Version tag for the image'
        required: false
        default: 'latest'

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '22'

      - name: Install pnpm
        run: |
          corepack enable
          corepack prepare pnpm@latest --activate

      - name: Get pnpm store directory
        shell: bash
        run: |
          echo "STORE_PATH=$(pnpm store path --silent)" >> $GITHUB_ENV

      - name: Setup pnpm cache
        uses: actions/cache@v4
        with:
          path: ${{ env.STORE_PATH }}
          key: ${{ runner.os }}-pnpm-store-${{ hashFiles('**/pnpm-lock.yaml') }}
          restore-keys: |
            ${{ runner.os }}-pnpm-store-

      - name: Install dependencies
        run: pnpm install --frozen-lockfile

      - name: Build all packages
        run: pnpm build

      - name: Prepare compiled output
        run: |
          mkdir -p compiled
          cp -r packages/cli/dist compiled/
          cp -r packages/core/dist compiled/
          cp -r packages/workflow/dist compiled/
          cp -r packages/nodes-base/dist compiled/
          cp -r node_modules compiled/
          cp package.json compiled/

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to Container Registry
        if: github.event_name != 'pull_request'
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: |
            type=ref,event=branch
            type=ref,event=pr
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=sha

      - name: Build and push Docker image
        uses: docker/build-push-action@v5
        with:
          context: .
          file: docker/images/n8n/Dockerfile
          push: ${{ github.event_name != 'pull_request' }}
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
          platforms: linux/amd64,linux/arm64

  test:
    needs: build
    runs-on: ubuntu-latest
    if: github.event_name != 'pull_request'

    steps:
      - name: Pull and test image
        run: |
          docker pull ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
          docker run --rm -d --name n8n-test \
            -p 5678:5678 \
            ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}

          # Wait for startup
          sleep 30

          # Health check
          curl -f http://localhost:5678/healthz || exit 1

          # Cleanup
          docker stop n8n-test
```

### Multi-Architecture Build

For ARM64 support (Apple Silicon, Raspberry Pi):

```yaml
platforms: linux/amd64,linux/arm64
```

### Publishing to Multiple Registries

```yaml
# Add Docker Hub login
- name: Log in to Docker Hub
  uses: docker/login-action@v3
  with:
    username: ${{ secrets.DOCKERHUB_USERNAME }}
    password: ${{ secrets.DOCKERHUB_TOKEN }}

# Update image names
images: |
  ghcr.io/${{ github.repository }}
  docker.io/your-org/n8n-custom
```

---

## Upstream Sync Strategy

### Recommended: Rebase-Based Workflow

Rebase keeps your customizations on top of upstream, making it clear what you've changed.

```bash
# 1. Fetch latest upstream changes
git fetch upstream

# 2. Checkout your main branch
git checkout main

# 3. Rebase onto upstream
git rebase upstream/master

# 4. Resolve any conflicts
# Edit conflicted files, then:
git add <resolved-files>
git rebase --continue

# 5. Force push to your fork (required after rebase)
git push origin main --force-with-lease

# 6. Rebase your customizations branch
git checkout customizations
git rebase main

# 7. Push customizations branch
git push origin customizations --force-with-lease
```

### Alternative: Merge-Based Workflow

Preserves full history but creates merge commits:

```bash
# 1. Fetch upstream
git fetch upstream

# 2. Merge upstream into main
git checkout main
git merge upstream/master

# 3. Resolve conflicts if any
git add <resolved-files>
git commit

# 4. Push
git push origin main

# 5. Merge main into customizations
git checkout customizations
git merge main
git push origin customizations
```

### Branch Strategy for Long-Term Forks

```
main (your fork's default branch)
│
├── upstream-sync          # Exact mirror of upstream/master
│   └── (auto-synced weekly)
│
├── customizations         # All your branding/config changes
│   ├── branding           # Logo, colors, text changes
│   ├── config             # Custom configuration
│   └── features           # Custom feature additions
│
└── release/*              # Release branches
    ├── release/2.1        # Based on n8n 2.1.x
    └── release/2.2        # Based on n8n 2.2.x
```

### Sync Schedule

| Frequency | Action |
|-----------|--------|
| Weekly | Fetch upstream, sync main branch |
| On n8n releases | Full sync + regression testing |
| Monthly | Review upstream changelog for breaking changes |
| Quarterly | Major version evaluation |

### Conflict Hotspots

Files most likely to conflict during upstream sync:

| File | Reason |
|------|--------|
| `packages/frontend/editor-ui/index.html` | Title changes |
| `packages/frontend/@n8n/design-system/src/css/_tokens.scss` | Color customizations |
| `packages/frontend/@n8n/i18n/src/locales/en.json` | Text changes |
| `package.json` (root and packages) | Version bumps |
| `pnpm-lock.yaml` | Dependency updates |
| `packages/frontend/editor-ui/public/*` | Logo replacements |

### Automated Sync with GitHub Actions

```yaml
# .github/workflows/upstream-sync.yml
name: Sync Upstream

on:
  schedule:
    - cron: '0 0 * * 0'  # Weekly on Sunday midnight
  workflow_dispatch:

jobs:
  sync:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0
          token: ${{ secrets.GITHUB_TOKEN }}

      - name: Configure Git
        run: |
          git config user.name "GitHub Actions Bot"
          git config user.email "actions@github.com"

      - name: Add upstream remote
        run: git remote add upstream https://github.com/n8n-io/n8n.git

      - name: Fetch upstream
        run: git fetch upstream

      - name: Check for updates
        id: check
        run: |
          BEHIND=$(git rev-list --count main..upstream/master)
          echo "behind=$BEHIND" >> $GITHUB_OUTPUT

      - name: Create sync PR
        if: steps.check.outputs.behind > 0
        uses: peter-evans/create-pull-request@v5
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
          commit-message: 'chore: sync with upstream n8n'
          title: 'Upstream Sync: ${{ steps.check.outputs.behind }} commits behind'
          body: |
            This PR syncs the fork with upstream n8n.

            **Commits behind:** ${{ steps.check.outputs.behind }}

            Please review changes and resolve any conflicts.
          branch: upstream-sync
          base: main
```

---

## Complete Fork Checklist

### Phase 1: Initial Fork Setup (Day 1-2)

- [ ] Fork n8n repository on GitHub
- [ ] Clone fork locally
- [ ] Configure upstream remote
- [ ] Install Node.js 22+ and enable corepack
- [ ] Run `pnpm install`
- [ ] Run `pnpm build` - verify success
- [ ] Run `pnpm test` - verify tests pass
- [ ] Run `pnpm start` - verify application works
- [ ] Access http://localhost:5678 - verify UI loads

### Phase 2: Branding Customization (Day 3-5)

- [ ] Create `customizations` branch
- [ ] Replace logos in `editor-ui/public/`
  - [ ] favicon-16x16.png
  - [ ] favicon-32x32.png
  - [ ] favicon.ico
  - [ ] n8n-logo.svg
  - [ ] n8n-logo-collapsed.svg
  - [ ] n8n-logo-expanded.svg
- [ ] Update color tokens in `design-system/src/css/_tokens.scss`
- [ ] Update dark theme in `design-system/src/css/_tokens.dark.scss`
- [ ] Modify brand text in `i18n/src/locales/en.json`
- [ ] Update window title in `editor-ui/index.html`
- [ ] Update title composable in `useDocumentTitle.ts`
- [ ] Test UI thoroughly - all pages
- [ ] Test in dark mode
- [ ] Commit all branding changes

### Phase 3: Enterprise Feature Decisions (Day 6-7)

- [ ] Audit .ee. file usage
- [ ] Document which enterprise features you need
- [ ] Choose approach:
  - [ ] Option A: Remove .ee. code entirely
  - [ ] Option B: Contact n8n for licensing
  - [ ] Option C: Build replacements (document scope)
- [ ] Implement chosen approach
- [ ] Test affected workflows

### Phase 4: Custom Features (Optional) (Week 2)

- [ ] Identify custom features needed
- [ ] Create feature branches
- [ ] Implement features
- [ ] Add tests for new features
- [ ] Document custom features
- [ ] Merge to customizations branch

### Phase 5: CI/CD Pipeline (Day 8-10)

- [ ] Create `.github/workflows/docker-build.yml`
- [ ] Set up container registry (GHCR, Docker Hub, or ECR)
- [ ] Configure registry credentials in GitHub Secrets
- [ ] Test manual workflow trigger
- [ ] Verify image builds successfully
- [ ] Verify image runs correctly
- [ ] Set up automated testing in pipeline
- [ ] Configure branch protection rules

### Phase 6: Deployment Integration (Day 11-12)

- [ ] Update docker-compose.yml to use custom image
- [ ] Test full stack with custom image
- [ ] Update backup/restore procedures
- [ ] Update documentation
- [ ] Train team on new procedures

### Phase 7: Maintenance Setup (Day 13-14)

- [ ] Document sync procedures
- [ ] Set up weekly sync schedule (manual or automated)
- [ ] Create regression test suite
- [ ] Document conflict resolution procedures
- [ ] Set up monitoring for upstream releases
- [ ] Create runbook for version upgrades

---

## Real-World Fork Examples

### Cerebrum-Tech/n8n-white-label

**Repository:** https://github.com/Cerebrum-Tech/n8n-white-label

A white-label version of n8n with customized branding.

**Key changes:**
- Custom logos and color scheme
- Modified brand text throughout
- Custom Docker build

### nocodb/n8n-fork

**Repository:** https://github.com/nocodb/n8n-fork

Fork used for NocoDB integration.

**Key changes:**
- Integration-specific modifications
- Custom nodes for NocoDB

### codeculturehq/n8n-custom-image

**Repository:** https://github.com/codeculturehq/n8n-custom-image

Automated custom Docker image builds.

**Key features:**
- Daily check for new n8n releases
- Automated Docker Hub publishing
- Version tracking workflow

---

## Effort Estimates

### Initial Setup

| Task | Effort | Dependencies |
|------|--------|--------------|
| Fork + clone + build verification | 4-8 hours | Node.js, pnpm |
| Basic branding (logos, colors, text) | 8-16 hours | Design assets |
| CI/CD pipeline setup | 4-8 hours | GitHub Actions knowledge |
| Docker registry configuration | 2-4 hours | Registry access |
| Initial documentation | 4-8 hours | - |
| **Total initial setup** | **22-44 hours (1-2 weeks)** | |

### Ongoing Maintenance

| Task | Frequency | Effort per Instance |
|------|-----------|---------------------|
| Upstream sync | Weekly | 1-2 hours |
| Conflict resolution | Per sync | 0-4 hours (varies) |
| Version upgrade testing | Monthly | 2-4 hours |
| Dependency updates | Monthly | 1-2 hours |
| Security patches | As needed | 2-4 hours |
| **Average weekly maintenance** | - | **2-4 hours** |

### Optional: Enterprise Feature Replacement

| Feature | Estimated Effort |
|---------|------------------|
| Basic SSO (OIDC) | 40-80 hours |
| SAML SSO | 80-120 hours |
| LDAP integration | 40-60 hours |
| Workflow sharing | 60-100 hours |
| Audit logging | 40-80 hours |
| Version control | 80-160 hours |

---

## Risks and Mitigations

### Risk Matrix

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| License violation | Medium | High | Legal review, internal-only use |
| Breaking upstream changes | High | Medium | Comprehensive tests, weekly sync |
| Merge conflicts | High | Low | Atomic commits, clear customization boundaries |
| Security vulnerabilities | Medium | High | Prompt upstream sync, security scanning |
| Build failures | Medium | Medium | CI/CD pipeline, local testing |
| Community node incompatibility | Low | Low | Test popular nodes after sync |
| Team knowledge gaps | Medium | Medium | Documentation, runbooks |
| Docker image bloat | Low | Low | Multi-stage builds, layer optimization |

### Mitigation Strategies

**1. License Compliance:**
- Document all use cases
- Keep fork internal-only
- Consult legal counsel before any commercial use
- Maintain clear records of customizations vs. upstream code

**2. Breaking Changes:**
- Subscribe to n8n release notifications
- Review changelogs before syncing
- Maintain staging environment for testing
- Create rollback procedures

**3. Conflict Management:**
- Keep customizations in separate, clearly-named files where possible
- Use feature flags for custom features
- Document all customization locations
- Create merge resolution runbook

**4. Security:**
- Enable Dependabot alerts
- Set up security scanning in CI/CD
- Sync security patches immediately
- Regular security audits

---

## Integration with Current Deployment

### Current Stack Overview

Your current deployment uses:
- Docker Compose orchestration
- Official `n8nio/n8n:2.1.4` image
- PostgreSQL 16.11-alpine
- Redis 7.4.7-alpine
- ngrok for external access
- 5 worker replicas

### Migration to Custom Fork

**1. Update docker-compose.yml:**

```yaml
services:
  n8n:
    # Before:
    # image: n8nio/n8n:2.1.4

    # After:
    image: ghcr.io/YOUR-ORG/n8n-custom:2.1.4
    # ... rest of config unchanged

  n8n-worker:
    # Before:
    # image: n8nio/n8n:2.1.4

    # After:
    image: ghcr.io/YOUR-ORG/n8n-custom:2.1.4
    # ... rest of config unchanged
```

**2. Authentication for private registry:**

```bash
# Login to GitHub Container Registry
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin

# Or add to docker-compose.yml environment
# Or use Docker config.json
```

**3. Update upgrade procedures:**

```bash
# Before (official image):
docker compose pull
docker compose up -d

# After (custom fork):
# 1. Build new version in CI/CD
# 2. Pull and deploy
docker compose pull
docker compose up -d
```

**4. Backup considerations:**

The custom fork uses the same data format as official n8n. Existing backups remain compatible.

### Version Tracking

Add to `.env`:

```bash
# Custom fork version tracking
N8N_FORK_VERSION=2.1.4-custom.1
N8N_UPSTREAM_VERSION=2.1.4
N8N_FORK_REPO=https://github.com/YOUR-ORG/n8n
```

---

## Sources

### Official n8n Resources

- [n8n GitHub Repository](https://github.com/n8n-io/n8n)
- [n8n License (Sustainable Use)](https://github.com/n8n-io/n8n/blob/master/LICENSE.md)
- [n8n White-Labelling Documentation](https://docs.n8n.io/embed/white-labelling/)
- [n8n Community Edition Features](https://docs.n8n.io/hosting/community-edition-features/)
- [n8n CONTRIBUTING.md](https://github.com/n8n-io/n8n/blob/master/CONTRIBUTING.md)
- [n8n Dockerfile](https://github.com/n8n-io/n8n/blob/master/docker/images/n8n/Dockerfile)
- [n8n SSO Documentation](https://docs.n8n.io/hosting/securing/set-up-sso/)

### Fork Examples

- [Cerebrum-Tech/n8n-white-label](https://github.com/Cerebrum-Tech/n8n-white-label)
- [nocodb/n8n-fork](https://github.com/nocodb/n8n-fork)
- [codeculturehq/n8n-custom-image](https://github.com/codeculturehq/n8n-custom-image)

### Git Fork Management

- [Atlassian Git Forks and Upstreams](https://www.atlassian.com/git/tutorials/git-forks-and-upstreams)
- [GitHub Blog: Friendly Fork Management](https://github.blog/2022-05-02-friend-zone-strategies-friendly-fork-management/)
- [History-Preserving Fork Maintenance](https://amboar.github.io/notes/2021/09/16/history-preserving-fork-maintenance-with-git.html)

### Docker and CI/CD

- [Docker Build Push Action](https://github.com/docker/build-push-action)
- [GitHub Container Registry](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)

---

## Conclusion

Creating a custom n8n fork is technically feasible and well-documented. The key considerations are:

1. **Licensing**: Only suitable for internal/non-commercial use without additional licensing
2. **Maintenance**: Expect 2-4 hours weekly for upstream sync and maintenance
3. **Enterprise features**: Plan for their absence or licensing cost
4. **Integration**: Your current Docker Compose stack requires minimal changes

The fork approach is recommended if you need:
- Custom branding throughout the application
- Modifications to core behavior
- Features not available in standard n8n
- Complete control over upgrade timing

For simpler customization needs, consider:
- Custom CSS injection (limited but no fork needed)
- Custom nodes (separate package, no fork needed)
- n8n Embed license (official white-label support)
