# Atlas Gitea container registry

The existing Gitea instance provides an OCI container registry at
`git.fscotto.co`. Gitea 1.25.2 enables packages by default; no separate
container, port, DNS record, or registry service is required. The existing
Gitea HTTPS proxy route is used. The setting applies to Gitea's package
registry generally, not only container images.

On 2026-10-25, both the Atlas HTTP endpoint and the public HTTPS `/v2/`
endpoint returned the expected `401` bearer authentication challenge. NPM's
effective `client_max_body_size` was `2000m`; larger individual requests may
be rejected. Authentication and an actual image push and pull have not yet
been tested. Do not interpret the unauthenticated challenge as a complete test.

## Use with Podman

Replace `OWNER`, `IMAGE`, and `TAG` with your Gitea user or organization and
image details. Log in interactively; use a personal access token when using
two-factor authentication. Do not put credentials in commands or shell history.

```sh
podman login git.fscotto.co
podman tag LOCAL_IMAGE:TAG git.fscotto.co/OWNER/IMAGE:TAG
podman push git.fscotto.co/OWNER/IMAGE:TAG
podman pull git.fscotto.co/OWNER/IMAGE:TAG
```

Choose the package's visibility and access deliberately in Gitea. Check the
package page and verify the pulled image digest when testing. No automatic
cleanup policy is configured by this document.

## Data and recovery

The observed package storage directory is
`/zpool/services/data/gitea/data/gitea/packages`, inside the existing Gitea
dataset. Package metadata also depends on the Gitea database and configuration.
Existing recursive ZFS and backup coverage must include both, but a successful
registry-specific backup and restore has not been tested. Review backup capacity
and consistency as image storage grows; a snapshot alone is not proof of an
application-consistent restore.

Reference: https://docs.gitea.com/1.25/usage/packages/container/
