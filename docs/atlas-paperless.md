# Paperless-ngx on Atlas

Atlas runs Paperless-ngx as six `admin`-owned rootless Quadlets:
Paperless 3.2.1, PostgreSQL 17, Valkey 8, Apache Tika 3.3.1.0 and
Gotenberg 8.37, and Ollama 0.40.3. State is isolated beneath
`zpool/services/data/paperless` in `data`, `media`, `consume`, `database` and
`cache`, and `ollama` datasets, so recursive ZFS snapshots, Borg and the UUID-bound USB
backup cover it without an application-specific backup job.

The only published listener is `192.168.178.55:8002`; Atlas firewalld admits it
only from Aegis. The database, broker and Office converters have no host
listener. Paperless is
configured with the canonical public URL `https://documents.fscotto.co`.

Ollama has no published host port and is reachable only on the private Paperless
container network. Paperless uses `qwen2.5:1.5b-instruct-q4_K_M` for suggestions
and chat and `nomic-embed-text:v1.5` for local document embeddings. Its context
is capped at 2048 tokens; Ollama is limited to 3 GiB, one loaded
model and one parallel request because Atlas has little spare RAM. Model files
are downloaded once from the Ollama registry; documents are not sent there.
The small language model trades answer quality and speed for resource safety.
Review AI-generated suggestions and answers before relying on them.

After the first deployment, build the LLM index when convenient (it may take
time and CPU proportional to the document count):

```sh
sudo -iu admin XDG_RUNTIME_DIR=/run/user/1000 \
  DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus \
  podman exec atlas-paperless document_llmindex rebuild
```

The scheduled incremental index update runs daily. After changing the
embedding model, rebuild the index again. App Configuration values in the
Paperless database take precedence over environment variables, so avoid setting
AI endpoint/backend overrides in the UI if Ansible should remain authoritative.

Tika and Gotenberg enable DOCX and other Office imports. Paperless retains the
original and produces a PDF rendition; this does not add in-browser editing.
Gotenberg disables Chromium JavaScript and restricts file access for email
conversion. A targeted role run probes both converters from inside Paperless.

## Initial deployment

The required encrypted-Vault fields are `vault_paperless_database_password`
and `vault_paperless_secret_key`; do not place them in host variables or paste
them into chat.  Generate unique values through the local Vault workflow before
the first run.  The service assertion deliberately rejects absent or weak
values.

Deploy with:

```sh
ANSIBLE_LOCAL_TEMP=/tmp/ansible-local \
  ansible-playbook ansible/site.yml --limit atlas --tags paperless --check --diff
ANSIBLE_LOCAL_TEMP=/tmp/ansible-local \
  ansible-playbook ansible/site.yml --limit atlas --tags paperless
```

After it is healthy, add an NPM Proxy Host manually on Prometheus for
`documents.fscotto.co` to `http://192.168.178.55:8002`, request its TLS
certificate, and keep Websocket Support enabled.  DNS and NPM remain explicit
operations and are not changed by the Paperless role.

Create the initial Paperless administrator interactively from an Atlas SSH
session; do not put an initial user password in the playbook or Vault:

```sh
sudo -iu admin XDG_RUNTIME_DIR=/run/user/1000 \
  DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus \
  podman exec -it atlas-paperless document_index reindex
sudo -iu admin XDG_RUNTIME_DIR=/run/user/1000 \
  DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus \
  podman exec -it atlas-paperless createsuperuser
```

The first command is optional for a new empty instance; it is included as a
safe way to ensure the index is current before using Paperless.  Put scanned
files in the private `consume` dataset only via an intentionally configured
source; Paperless consumes and moves them into its managed media store.
