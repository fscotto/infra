#!/usr/bin/python3
"""Private NPM-only JSON-RPC adapter. Never serves the secret to browsers."""
import argparse
import copy
import http.client
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import threading

MAX_BODY = 2 * 1024 * 1024


def inject(request, token, depth=0):
    if depth > 4 or not isinstance(request, dict):
        raise ValueError('Invalid RPC request')
    result = copy.deepcopy(request)
    method = result.get('method', result.get('methodName'))
    params = result.setdefault('params', [])
    if not isinstance(method, str) or not isinstance(params, list):
        raise ValueError('Invalid RPC method or params')
    if method == 'system.multicall':
        if len(params) != 1 or not isinstance(params[0], list) or len(params[0]) > 128:
            raise ValueError('Invalid multicall')
        result['params'] = [[inject(item, token, depth + 1) for item in params[0]]]
    elif method.startswith('aria2.'):
        if params and isinstance(params[0], str) and params[0].startswith('token:'):
            params.pop(0)
        # Keep RPC security configuration owned by Ansible, not remote callers.
        if method in ('aria2.changeGlobalOption', 'aria2.changeOption'):
            for value in params:
                if isinstance(value, dict) and any(key.startswith('rpc-') for key in value):
                    raise ValueError('RPC security options are not editable')
        params.insert(0, 'token:' + token)
    elif method not in ('system.listMethods', 'system.listNotifications'):
        raise ValueError('Unsupported RPC method')
    return result


def sanitize(value, token):
    if isinstance(value, dict):
        return {key: sanitize(item, token) for key, item in value.items()
                if key not in ('rpc-secret', 'rpc-passwd', 'rpc-user')}
    if isinstance(value, list):
        return [sanitize(item, token) for item in value]
    if isinstance(value, str):
        return value.replace(token, '[redacted]')
    return value


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--listen', required=True)
    parser.add_argument('--port', type=int, required=True)
    parser.add_argument('--upstream-port', type=int, required=True)
    parser.add_argument('--peer', required=True)
    parser.add_argument('--domain', required=True)
    parser.add_argument('--secret-file', required=True)
    args = parser.parse_args()
    token = Path(args.secret_file).read_text().strip()
    if len(token) != 64 or any(char not in '0123456789abcdef' for char in token):
        raise ValueError('Invalid private RPC secret')
    slots = threading.BoundedSemaphore(16)

    class Handler(BaseHTTPRequestHandler):
        def setup(self):
            super().setup()
            self.connection.settimeout(15)

        def log_message(self, *_):
            pass  # No credentials, download URLs or request payloads in logs.

        def reply(self, status, value):
            body = json.dumps(value).encode()
            self.send_response(status)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Cache-Control', 'no-store')
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def do_POST(self):
            if self.client_address[0] not in (args.peer, args.listen):
                return self.reply(403, {'error': 'Forbidden'})
            if self.path != '/jsonrpc' or self.headers.get('Host') not in (args.domain, args.domain + ':443'):
                return self.reply(403, {'error': 'Forbidden'})
            origin = self.headers.get('Origin')
            if origin and origin != 'https://' + args.domain:
                return self.reply(403, {'error': 'Forbidden origin'})
            if self.headers.get('Transfer-Encoding') or self.headers.get('Content-Type', '').split(';')[0].strip() not in ('application/json', 'application/json-rpc'):
                return self.reply(415, {'error': 'JSON POST required'})
            if not slots.acquire(blocking=False):
                return self.reply(503, {'error': 'Busy'})
            connection = None
            try:
                length = int(self.headers.get('Content-Length', '0'))
                if not 0 < length <= MAX_BODY:
                    return self.reply(413, {'error': 'Invalid request size'})
                request = json.loads(self.rfile.read(length))
                if isinstance(request, list):
                    if not 0 < len(request) <= 128:
                        raise ValueError('Invalid batch')
                    request = [inject(item, token) for item in request]
                else:
                    request = inject(request, token)
                body = json.dumps(request).encode()
                if len(body) > MAX_BODY:
                    return self.reply(413, {'error': 'Request too large'})
                connection = http.client.HTTPConnection(args.listen, args.upstream_port, timeout=30)
                connection.request('POST', '/jsonrpc', body, {'Content-Type': 'application/json'})
                response = connection.getresponse()
                payload = response.read(MAX_BODY + 1)
                if len(payload) > MAX_BODY:
                    return self.reply(502, {'error': 'Upstream response too large'})
                self.reply(response.status, sanitize(json.loads(payload), token))
            except (ValueError, TypeError, KeyError):
                self.reply(400, {'error': 'Invalid RPC request'})
            except (OSError, http.client.HTTPException):
                self.reply(502, {'error': 'RPC upstream unavailable'})
            finally:
                if connection:
                    connection.close()
                slots.release()

    server = ThreadingHTTPServer((args.listen, args.port), Handler)
    server.daemon_threads = True
    server.serve_forever()


if __name__ == '__main__':
    main()
