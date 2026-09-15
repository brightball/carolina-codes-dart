# Quality gates shared by local pre-commit and Gitea jobs.
# mise.toml pins dart, gitleaks, and osv-scanner.
export PATH := $(HOME)/.local/bin:$(HOME)/.local/share/mise/shims:$(PATH)

.PHONY: deps test sast vuln secrets fmt fmt-check check hooks

deps:
	dart pub get

test: deps
	dart test

sast: deps
	dart analyze --fatal-infos

vuln:
	osv-scanner scan source --lockfile=pubspec.lock

secrets:
	gitleaks detect --source . --verbose --no-git

fmt:
	dart format .

fmt-check:
	dart format --output=none --set-exit-if-changed .

check: test sast vuln secrets fmt-check

hooks:
	pre-commit install
	git config core.hooksPath .githooks
