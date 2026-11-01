import importlib.util
import os
from pathlib import Path
import sys
import tempfile
from types import ModuleType
import unittest
from unittest.mock import Mock, patch


class SeparationWorkerTest(unittest.TestCase):
    def test_convert_only_applies_mia_voce_without_importing_separator(self):
        spec = importlib.util.spec_from_file_location(
            'preset_rvc', Path(__file__).resolve().parents[1] / 'files/preset_rvc.py')
        worker = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(worker)
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            output = root / 'output'
            job = output / 'job'
            job.mkdir(parents=True)
            source = job / 'audio.wav'
            source.write_bytes(b'audio')
            weights = root / 'state/weights/mia_voce.pth'
            index = root / 'state/mia_voce/added_IVF256_Flat_nprobe_1_mia_voce_v2.index'
            for path in (weights, index):
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(b'model')

            def mapped_path(value):
                return root / str(value).removeprefix('/work/') if str(value).startswith(
                    '/work/') else Path(value)

            config = ModuleType('configs.config')
            config.Config = Mock()
            vc = ModuleType('infer.vc.modules')
            voice = Mock()
            voice.vc_single.return_value = ('Success', (40000, [0.1, 0.2]))
            vc.VC = Mock(return_value=voice)
            sf = ModuleType('soundfile')
            sf.write = Mock(side_effect=lambda path, data, rate: path.write_bytes(b'converted'))
            modules = {'configs.config': config, 'infer.vc.modules': vc,
                       'soundfile': sf, 'tools.pymss_webui': None}
            with patch.object(worker, 'Path', mapped_path), \
                    patch.object(sys, 'argv', ['preset_rvc.py', str(source), str(job),
                                               '--convert-only']), \
                    patch.dict(sys.modules, modules), patch.dict(os.environ):
                worker.main()
            voice.get_vc.assert_called_once_with('mia_voce.pth')
            self.assertEqual(voice.vc_single.call_args.args[1], str(source))
            self.assertEqual(voice.vc_single.call_args.args[4], str(index))
            self.assertEqual((job / 'vocals-mia_voce.wav').read_bytes(), b'converted')
            self.assertFalse((job / 'vocals').exists())
            self.assertFalse((job / 'instrumental').exists())

    def test_separate_only_does_not_require_personal_voice_weights(self):
        spec = importlib.util.spec_from_file_location(
            'preset_rvc', Path(__file__).resolve().parents[1] / 'files/preset_rvc.py')
        worker = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(worker)
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            job = output / 'job'
            job.mkdir()
            source = job / 'audio.wav'
            source.write_bytes(b'fixture')
            separator = ModuleType('tools.pymss_webui')

            def separate(model, audio, vocals, unused, instrumental, fmt, **kwargs):
                self.assertEqual(model, 'vocals-bs-roformer-368')
                self.assertEqual(audio, str(source))
                (Path(vocals) / 'stem.wav').write_bytes(b'vocals')
                (Path(instrumental) / 'stem.wav').write_bytes(b'instrumental')
                yield 'Separated'

            separator.pymss_separate = separate

            def mapped_path(value):
                return output if str(value) == '/work/output' else Path(value)

            with patch.object(worker, 'Path', mapped_path), \
                    patch.object(sys, 'argv', ['preset_rvc.py', str(source), str(job),
                                               '--separate-only']), \
                    patch.dict(sys.modules, {'tools.pymss_webui': separator}), \
                    patch.dict(os.environ):
                worker.main()
            self.assertTrue((job / 'vocals/stem.wav').is_file())
            self.assertTrue((job / 'instrumental/stem.wav').is_file())
            self.assertFalse((job / 'vocals-mia_voce.wav').exists())


if __name__ == '__main__':
    unittest.main()
