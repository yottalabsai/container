## Summary

<!-- What does this PR do? Which template(s) does it affect? -->

## Type of Change

- [ ] New template
- [ ] Update to existing template (version bump, new packages, etc.)
- [ ] Bug fix
- [ ] Shared infrastructure change (`container-template/`)
- [ ] Documentation only

## Checklist

- [ ] `Dockerfile` builds successfully (`docker buildx bake <target> --no-cache`)
- [ ] Container starts and all services are reachable
- [ ] `README.md` updated to reflect any interface or version changes
- [ ] No secrets, tokens, or internal hostnames committed
- [ ] `docker-bake.hcl` target name and image tag are correct

## Test Notes

<!-- How did you test this? Include any relevant commands or outputs. -->
