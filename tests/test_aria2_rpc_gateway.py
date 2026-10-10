"""Offline regression tests for the private RPC adapter (no real credentials)."""
import importlib.util
from pathlib import Path
import unittest

path = Path(__file__).resolve().parents[1] / 'ansible/roles/profile_atlas/files/atlas-aria2-rpc-gateway.py'
spec = importlib.util.spec_from_file_location('gateway', path)
gateway = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gateway)


class GatewayTests(unittest.TestCase):
    def test_insert_without_mutating(self):
        request = {'method': 'aria2.getVersion', 'params': []}
        self.assertEqual(gateway.inject(request, 'test')['params'], ['token:test'])
        self.assertEqual(request['params'], [])

    def test_replace_stale_token(self):
        self.assertEqual(gateway.inject({'method': 'aria2.tellActive', 'params': ['token:old']}, 'test')['params'], ['token:test'])

    def test_multicall(self):
        request = {'method': 'system.multicall', 'params': [[{'methodName': 'aria2.getVersion', 'params': []}]]}
        self.assertEqual(gateway.inject(request, 'test')['params'][0][0]['params'], ['token:test'])

    def test_security_option_edits_rejected(self):
        for method in ('aria2.changeOption', 'aria2.changeGlobalOption'):
            with self.assertRaises(ValueError):
                gateway.inject({'method': method, 'params': [{'rpc-secret': 'new'}]}, 'test')

    def test_malformed_requests_rejected(self):
        for request in (None, {}, {'method': 'bad'}, {'method': 'system.multicall', 'params': []}, {'method': 'aria2.getVersion', 'params': {}}):
            with self.assertRaises(ValueError):
                gateway.inject(request, 'test')

    def test_response_secret_filtering(self):
        self.assertEqual(gateway.sanitize({'result': [{'rpc-secret': 'test', 'rpc-user': 'user', 'rpc-passwd': 'pw', 'value': 'token:test'}]}, 'test'), {'result': [{'value': 'token:[redacted]'}]})


if __name__ == '__main__':
    unittest.main()
