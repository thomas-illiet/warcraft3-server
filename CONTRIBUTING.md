# Contributing

Thank you for helping keep this project reproducible and easy to audit.

## Development setup

Clone with submodules and verify that their worktrees match the recorded commits:

```sh
git clone --recurse-submodules https://github.com/thomas-illiet/warcraft3-server.git
cd warcraft3-server
git submodule status --recursive
```

Use English for filenames, documentation, comments, menus, messages and commit subjects. Do not commit generated binaries, archives, build trees, checksums, IDE metadata, downloaded toolchains or Blizzard files.

Keep upstream source changes outside the submodules. W3L compatibility changes belong in `patch/build/w3l-mingw.patch` and must continue to pass `git -C sources/w3l apply --check ../../patch/build/w3l-mingw.patch`.

## Commit style

Use Conventional Commits without scopes:

```text
feat: add a portable runtime option
fix: keep the selected realm after editing
docs: clarify LAN address translation
```

Keep commits focused. Do not use subjects such as `feat(server): ...` because this repository intentionally avoids commit scopes.

## Checks

Before opening a pull request, run the checks relevant to the change:

```powershell
Invoke-Pester ./tests
Invoke-ScriptAnalyzer -Path ./patch -Recurse -Settings ./PSScriptAnalyzerSettings.psd1
```

```sh
mapfile -t shell_scripts < <(git ls-files '*.sh')
shellcheck "${shell_scripts[@]}"
docker compose --file server/docker/compose.yaml config
helm lint server/helm --strict
helm template ci server/helm --kube-version 1.25.0 \
  --set-string server.publicIp=203.0.113.10 >/dev/null
go run github.com/rhysd/actionlint/cmd/actionlint@v1.7.7
```

Build or smoke-test any distribution that changed. Pull requests build temporary artifacts but never publish packages or images.

## Releases

Maintainers create releases by pushing a semantic version tag after `main` is green. Never commit release output. The workflow creates archives and checksums from the tagged source and updates `latest` only for stable versions.
