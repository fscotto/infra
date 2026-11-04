# Keep Go's workspace out of the home directory root.
export GOPATH="$HOME/.local/share/Go"
case ":$PATH:" in
  *":$GOPATH/bin:"*) ;;
  *) PATH="$GOPATH/bin:$PATH" ;;
esac
export PATH
