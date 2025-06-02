# GitLeaks Configuration Notes

## Allowlisted Secrets

This repository contains some example secrets in documentation files that are intentionally allowlisted in our `.gitleaks.toml` configuration. These are not real secrets but are included as part of code examples or documentation to illustrate proper configuration patterns.

### Current allowlisted secrets:

1. `aws_secret= "AKIAIMNOJVGFDXXXE4OA"` - This is a sample AWS key used in examples
2. `export BUNDLE_ENTERPRISE__CONTRIBSYS__COM=cafebabe:deadbeef` - This is a sample key used in examples

## How Our Allowlist Works

In our `.gitleaks.toml` file, we've configured the allowlist like this:

```toml
[allowlist]
description = "Allowlisted files and patterns"
paths = [
  # Other paths...
  '''README\.md$'''  # Allow in README.md file
]
regexes = [
  # Other patterns...
  '''aws_secret= \"AKIAIMNOJVGFDXXXE4OA\"''',
  '''AKIAIMNOJVGFDXXXE4OA''',
  '''export BUNDLE_ENTERPRISE__CONTRIBSYS__COM=cafebabe:deadbeef'''
]
```

This configuration tells GitLeaks to ignore these specific patterns in our README.md file.

## Why We Use Allowlisting

We use allowlisting instead of removing these example secrets because:

1. They are explicitly fake/sample secrets used for documentation purposes
2. They help illustrate proper configurations or setup instructions
3. Removing them might make the documentation less clear for users

## Important Security Notes

- **Never** commit real credentials to this repository
- Always use environment variables, Key Vault, or other secure methods to manage real secrets
- If you need to include a sample secret in documentation, use obvious fake values (e.g., "EXAMPLE-KEY-12345")
- When possible, add the `#GitLeaksIgnore` comment to lines containing example secrets

## Running Secret Scans

To scan for real secrets that might have been accidentally committed, run:

### PowerShell:

```powershell
# From repository root
.\azd-hooks\scripts\hooks\preprovision\run_gitleaks.ps1
```

## What To Do If Real Secrets Are Found

If real secrets are detected:

1. **Immediately revoke and rotate the credentials**
2. Use tools like BFG Repo-Cleaner to remove the secrets from Git history
3. Add proper allowlist entries only for example/documentation secrets
4. Review your Git workflow to prevent future leaks
