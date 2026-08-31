# Activate Mise for interactive Bash sessions, including JAVA_HOME for its JDKs.
if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate bash)"
fi
