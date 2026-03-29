# Setup Conflux

A GitHub Action and shell installer for the [Conflux](https://github.com/coroslabs/conflux) CLI. Both methods download the binary from private GitHub Releases, verify its SHA-256 checksum, and make it available on `PATH`. The GitHub Action also caches the binary across workflow runs.

## Prerequisites

Conflux is distributed as a private release. You need a token with `contents:read` on `coroslabs/conflux` to download it.

### Option A: GitHub App (recommended for CI)

1. Create a GitHub App in the `coroslabs` organisation with **Contents: read-only** permission
2. Install the app on **Only select repositories** → `coroslabs/conflux`
3. Generate a token from the app (via API or CLI) and store it as a GitHub Actions secret named `CONFLUX_GITHUB_TOKEN`

### Option B: Fine-grained PAT

1. Go to **GitHub > Settings > Developer settings > [Fine-grained personal access tokens](https://github.com/settings/personal-access-tokens/new)**
2. Set **Resource owner** to `coroslabs`
3. Under **Repository access**, select **Only select repositories** and choose `coroslabs/conflux`
4. Under **Permissions > Repository permissions**, set **Contents** to **Read**
5. Generate the token and store it as a GitHub Actions secret named `CONFLUX_GITHUB_TOKEN`

## GitHub Actions usage

### Inputs

| Input          | Required | Default    | Description                                                              |
|----------------|----------|------------|--------------------------------------------------------------------------|
| `version`      | No       | `latest`   | Version to install. Use `latest` or a specific tag (e.g., `v0.5.0`).    |
| `github-token` | Yes      | —          | Token with `contents:read` on `coroslabs/conflux`. Can be a GitHub App token, fine-grained PAT, or any token with the required scope. |

### Outputs

| Output      | Description                                    |
|-------------|------------------------------------------------|
| `version`   | The resolved version that was installed         |
| `cache-hit` | Whether the binary was restored from cache      |

### Version pinning

For convenience, pin to a major version tag:

```yaml
uses: coroslabs/setup-conflux@v1
```

For stricter security (recommended in production), pin to a specific commit SHA:

```yaml
uses: coroslabs/setup-conflux@<commit-sha>
```

### Workflow example

```yaml
name: Conflux sync
on:
  pull_request:
    types: [opened, synchronize]

permissions:
  contents: read
  pull-requests: write

jobs:
  sync:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install Conflux
        uses: coroslabs/setup-conflux@v1
        with:
          version: 'latest'
          github-token: ${{ secrets.CONFLUX_GITHUB_TOKEN }}

      - name: Run Conflux
        run: conflux version
```

## Shell installer

The shell installer is for developer machines running macOS or Linux.

### Environment variables

| Variable              | Required | Default             | Description                                           |
|-----------------------|----------|---------------------|-------------------------------------------------------|
| `GITHUB_TOKEN`        | Yes      | —                   | Token with `contents:read` on `coroslabs/conflux`.    |
| `CONFLUX_VERSION`     | No       | `latest`            | Version to install (e.g., `v0.5.0`).                  |
| `CONFLUX_INSTALL_DIR` | No       | `$HOME/.local/bin`  | Directory to install the binary into.                 |
| `HTTPS_PROXY`         | No       | —                   | HTTPS proxy for environments behind a corporate proxy.|

### Usage

Install the latest version:

```bash
GITHUB_TOKEN=ghp_xxx bash <(curl -fsSL https://raw.githubusercontent.com/coroslabs/setup-conflux/main/install.sh)
```

Install a specific version:

```bash
GITHUB_TOKEN=ghp_xxx CONFLUX_VERSION=v0.5.0 bash <(curl -fsSL https://raw.githubusercontent.com/coroslabs/setup-conflux/main/install.sh)
```

Install to a custom directory:

```bash
GITHUB_TOKEN=ghp_xxx CONFLUX_INSTALL_DIR=/usr/local/bin bash <(curl -fsSL https://raw.githubusercontent.com/coroslabs/setup-conflux/main/install.sh)
```

After installation, ensure the install directory is on your `PATH`:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

## Go install

If you have Go installed, you can build from source:

```bash
GOPRIVATE=github.com/phaestostech/* go install github.com/phaestostech/conflux@latest
```

> **Note:** The Go module path (`phaestostech`) differs from the GitHub organisation (`coroslabs`). This is expected — the binary is distributed under `coroslabs` but the Go module is hosted under `phaestostech`.

## Security

- **Mandatory checksum verification** — both the GitHub Action and shell installer verify SHA-256 checksums from `checksums.txt` before extracting. There is no flag to skip this step.
- **Token handling** — the token is passed via environment variable and is never logged. In GitHub Actions, use repository secrets to store tokens.
- **No bypass flags** — checksum verification cannot be disabled. If a checksum does not match, the installation fails.

## Troubleshooting

| Symptom                       | Cause                                          | Fix                                                                        |
|-------------------------------|-------------------------------------------------|----------------------------------------------------------------------------|
| `conflux: command not found`  | Setup step missing or PATH not configured       | Add the `setup-conflux` step before running conflux commands               |
| `401 Unauthorized`            | Token missing, expired, or lacking scope        | Verify the token has `contents:read` on `coroslabs/conflux`                |
| `Checksum mismatch`           | Corrupted download or tampered release          | Retry the download; if persistent, check the release for corruption        |
| `Unsupported OS/architecture` | Running on an unsupported platform              | Use Linux/macOS on amd64 or arm64; Windows is supported in GitHub Actions  |

## Required permissions

| Scope              | Permission       | Purpose                          |
|--------------------|------------------|----------------------------------|
| `coroslabs/conflux`| `contents:read`  | Download release assets          |

No other permissions are required. The token does not need write access, workflow access, or access to any other repository.

## License

[MIT](LICENSE)
