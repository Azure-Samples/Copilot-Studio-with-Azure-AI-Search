FROM mcr.microsoft.com/devcontainers/go:1.4.1-bullseye

USER root

# Normalize Yarn apt source and key so downstream feature apt operations succeed.
RUN set -eux; \
	rm -f /etc/apt/sources.list.d/yarn.list /etc/apt/sources.list.d/yarn.list.save; \
	export GNUPGHOME="$(mktemp -d)"; \
	mkdir -p /usr/share/keyrings; \
	curl -fsSL https://dl.yarnpkg.com/debian/pubkey.gpg -o /tmp/yarn-pubkey.gpg; \
	gpg --dearmor --batch --yes -o /usr/share/keyrings/yarn-archive-keyring.gpg /tmp/yarn-pubkey.gpg; \
	chmod 0644 /usr/share/keyrings/yarn-archive-keyring.gpg; \
	echo "deb [signed-by=/usr/share/keyrings/yarn-archive-keyring.gpg] https://dl.yarnpkg.com/debian/ stable main" > /etc/apt/sources.list.d/yarn.list; \
	rm -rf "$GNUPGHOME" /tmp/yarn-pubkey.gpg; \
	rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* /tmp/* /root/.gnupg /home/vscode/.gnupg

USER vscode