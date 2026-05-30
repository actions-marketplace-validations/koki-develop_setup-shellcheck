# setup-shellcheck

A GitHub Action to install [ShellCheck](https://github.com/koalaman/shellcheck), a static analysis tool for shell scripts.

## Usage

<!-- x-release-please-start-version -->
```yaml
- uses: koki-develop/setup-shellcheck@v1.0.2
```
<!-- x-release-please-end -->

### Inputs

| Name | Description | Default |
| --- | --- | --- |
| `version` | Version to install (e.g. `X.Y.Z`, `vX.Y.Z`, or `latest`) | `latest` |
| `token` | GitHub token for API requests (to avoid rate limiting) | `${{ github.token }}` |

### Example

<!-- x-release-please-start-version -->
```yaml
name: shellcheck

on:
  pull_request:
  push:
    branches: [main]

jobs:
  shellcheck:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
      - uses: koki-develop/setup-shellcheck@v1.0.2
      - run: shellcheck script.sh
```
<!-- x-release-please-end -->

## License

[MIT](./LICENSE)
