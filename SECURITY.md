# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in this repository, please **do not open a public GitHub issue**.

Instead, report it privately by emailing **security@yottalabs.ai**. Include:

- A description of the vulnerability
- Steps to reproduce
- The affected template(s) or file(s)
- Any potential impact

We will acknowledge your report within **48 hours** and aim to provide a resolution or mitigation within **14 days**, depending on severity.

## Scope

This policy covers:

- Dockerfiles and build scripts in this repository
- The shared `container-template/` infrastructure (`start.sh`, Nginx config)
- Documentation that could mislead users into insecure configurations

## Out of Scope

- Vulnerabilities in upstream packages or base images (report these to the relevant upstream project)
- Issues in the Yotta platform itself (contact support@yottalabs.ai)

## Best Practices for Users

- Never commit API tokens, passwords, or private keys to this repository
- Pass secrets at runtime via environment variables, not build arguments
- Regularly rebuild images to pull in upstream security patches
- Mount `/workspace` as a persistent volume rather than storing data in the container layer
