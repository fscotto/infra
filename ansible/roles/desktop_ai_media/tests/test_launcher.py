import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import unittest
import wave
import struct

from jinja2 import Environment
import shlex

ROLE = Path(__file__).resolve().parents[1]


class LauncherTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.media = self.root / '.local/share/ai-media'
        for directory in ('input', 'output', 'models', 'state/facefusion', 'state/rvc'):
            (self.media / directory).mkdir(parents=True)
        environment = Environment()
        environment.filters['quote'] = shlex.quote
        self.launcher = self.root / 'ai-media'
        self.launcher.write_text(environment.from_string(
            (ROLE / 'templates/ai-media.j2').read_text()
        ).render(desktop_ai_media_root=str(self.media), desktop_ai_media_build_root=str(self.root)))
        (self.root / 'check_storage.py').write_text((ROLE / 'files/check_storage.py').read_text())
        for name in ('preset.py', 'preset_rvc.py'):
            (self.root / name).write_text((ROLE / 'files' / name).read_text())
        self.log = self.root / 'podman.json'
        podman = self.root / 'podman'
        podman.write_text('#!/usr/bin/python3\nimport json,os,sys\n'
                          'open(os.environ["TEST_LOG"], "w").write(json.dumps(sys.argv[1:]))\n')
        podman.chmod(0o755)
        self.env = dict(os.environ, PATH=str(self.root) + ':' + os.environ['PATH'],
                        TEST_LOG=str(self.log), HOME=str(self.root))

    def launch(self, *args):
        return subprocess.run(['bash', str(self.launcher), *args], env=self.env,
                              capture_output=True, text=True)

    def fake_media_launcher(self):
        fake = self.root / 'fake-ai-media'
        fake.write_text('''#!/usr/bin/python3
import os
from pathlib import Path
import shutil
import sys

root = Path(os.environ["TEST_MEDIA"])
def host(path):
    return str(path).replace("/work/input/", str(root / "input") + "/").replace(
        "/work/output/", str(root / "output") + "/")

tool = sys.argv[1]
args = sys.argv[2:]
if tool == "ffmpeg":
    os.execvp("ffmpeg", ["ffmpeg", *[host(arg) for arg in args]])
if tool == "facefusion":
    (root / "facefusion-args.json").write_text(__import__("json").dumps(args))
    shutil.copyfile(host(args[args.index("--target-path") + 1]),
                    host(args[args.index("--output-path") + 1]))
    raise SystemExit(0)
if tool == "rvc":
    (root / "rvc-args.json").write_text(__import__("json").dumps(args))
    source = Path(host(args[1]))
    job = Path(host(args[2]))
    if "--convert-only" not in args:
        (job / "instrumental").mkdir()
        shutil.copyfile(source, job / "instrumental/stem.wav")
    if "--separate-only" in args:
        (job / "vocals").mkdir()
        shutil.copyfile(source, job / "vocals/stem.wav")
    else:
        shutil.copyfile(source, job / "vocals-mia_voce.wav")
    raise SystemExit(0)
raise SystemExit("Unexpected tool: " + tool)
''')
        fake.chmod(0o755)
        return fake

    def fake_downloader(self, fixture):
        downloader = self.root / 'yt-dlp'
        downloader.write_text('''#!/usr/bin/python3
import json
import os
from pathlib import Path
import shutil
import sys

args = sys.argv[1:]
Path(os.environ["TEST_LOG"]).write_text(json.dumps(args))
destination = args[args.index("--output") + 1].replace("%(ext)s", "mp4")
shutil.copyfile(os.environ["TEST_DOWNLOAD_FIXTURE"], destination)
''')
        downloader.chmod(0o755)
        self.env['TEST_DOWNLOAD_FIXTURE'] = str(fixture)
        return downloader

    def run_preset(self, fake, *args, job_id='test'):
        return subprocess.run(['python3', str(self.root / 'preset.py'),
                               str(self.media), str(fake), '--run', '--job-id', job_id, *args],
                              env={**self.env, 'TEST_MEDIA': str(self.media)},
                              capture_output=True, text=True)

    def create_video(self, *, audio=False):
        video = self.media / 'input/video1.mp4'
        command = ['ffmpeg', '-hide_banner', '-loglevel', 'error', '-f', 'lavfi',
                   '-i', 'color=c=black:s=64x64:d=1']
        if audio:
            command += ['-f', 'lavfi', '-i', 'sine=frequency=440:duration=1']
        command += ['-c:v', 'mpeg4']
        if audio:
            command += ['-c:a', 'aac', '-shortest']
        subprocess.run([*command, str(video)], check=True)
        return video

    def stream_types(self, path):
        probe = subprocess.check_output(['ffprobe', '-v', 'error', '-show_entries',
                                         'stream=codec_type', '-of', 'json', str(path)])
        return {stream['codec_type'] for stream in json.loads(probe)['streams']}

    def create_audio(self, relative, sample=1000, seconds=1):
        path = self.media / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        with wave.open(str(path), 'wb') as audio:
            audio.setparams((1, 2, 8000, 0, 'NONE', 'not compressed'))
            audio.writeframes(struct.pack('<h', sample) * (8000 * seconds))
        return path

    def test_mix_sums_stems_and_preserves_longest_duration(self):
        vocals = self.create_audio('output/video1-split-stems/vocals.wav')
        instrumental = self.create_audio('output/video1-split-stems/instrumental.wav',
                                         sample=2000, seconds=2)
        before = [path.read_bytes() for path in (vocals, instrumental)]
        result = self.run_preset(self.fake_media_launcher(), 'mix',
                                 'video1-split-stems/vocals.wav',
                                 'video1-split-stems/instrumental.wav', '--output', 'song.wav')
        self.assertEqual(result.returncode, 0, result.stderr)
        output = self.media / 'output/song.wav'
        self.assertEqual(self.stream_types(output), {'audio'})
        with wave.open(str(output), 'rb') as audio:
            self.assertEqual(audio.getnframes(), 16000)
            samples = struct.unpack('<16000h', audio.readframes(16000))
            self.assertAlmostEqual(samples[4000], 3000, delta=1)
            self.assertAlmostEqual(samples[12000], 2000, delta=1)
        self.assertEqual([path.read_bytes() for path in (vocals, instrumental)], before)

    def test_voice_convert_audio_skips_separation_and_preserves_input(self):
        source = self.create_audio('output/video1-split-stems/vocals.wav')
        before = source.read_bytes()
        result = self.run_preset(self.fake_media_launcher(), 'voice-convert',
                                 'video1-split-stems/vocals.wav')
        self.assertEqual(result.returncode, 0, result.stderr)
        output = self.media / 'output/vocals-mia_voce.wav'
        self.assertEqual(self.stream_types(output), {'audio'})
        args = json.loads((self.media / 'rvc-args.json').read_text())
        self.assertIn('--convert-only', args)
        self.assertFalse(list((self.media / 'output').rglob('instrumental')))
        self.assertFalse((self.media / 'facefusion-args.json').exists())
        self.assertEqual(source.read_bytes(), before)
        repeated = self.run_preset(self.fake_media_launcher(), 'voice-convert',
                                   'video1-split-stems/vocals.wav')
        self.assertNotEqual(repeated.returncode, 0)

    def test_voice_convert_dispatches_with_custom_output(self):
        self.create_audio('input/voice.wav')
        runner = self.root / 'systemd-run'
        runner.write_text('#!/usr/bin/python3\nimport json,os,sys\n'
                          'open(os.environ["TEST_LOG"], "w").write(json.dumps(sys.argv[1:]))\n')
        runner.chmod(0o755)
        result = self.launch('preset', 'voice-convert', 'voice.wav', '--output', 'mine.wav')
        self.assertEqual(result.returncode, 0, result.stderr)
        args = json.loads(self.log.read_text())
        self.assertIn('--user', args)
        self.assertEqual(args[-4:], ['voice-convert', 'voice.wav', '--output', 'mine.wav'])

    def test_voice_convert_rejects_invalid_audio_and_output(self):
        self.create_audio('input/voice.wav')
        for name in ('missing.wav', '../voice.wav', 'https://example.org/audio.wav'):
            self.assertNotEqual(self.launch('preset', 'voice-convert', name).returncode, 0)
        for name in ('../mine.wav', 'mine.mp3'):
            self.assertNotEqual(self.launch('preset', 'voice-convert', 'voice.wav',
                                           '--output', name).returncode, 0)
        self.create_audio('output/voice.wav')
        self.assertNotEqual(self.launch('preset', 'voice-convert', 'voice.wav').returncode, 0)
        self.assertFalse(self.log.exists())

    def test_mix_default_output_and_no_overwrite(self):
        self.create_audio('input/voice.wav')
        self.create_audio('output/instrumental.wav')
        args = ('mix', 'voice.wav', 'instrumental.wav')
        result = self.run_preset(self.fake_media_launcher(), *args)
        self.assertEqual(result.returncode, 0, result.stderr)
        target = self.media / 'output/voice-mix.wav'
        original = target.read_bytes()
        result = self.run_preset(self.fake_media_launcher(), *args)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(target.read_bytes(), original)

    def test_mix_dispatches_audio_only_background_job(self):
        self.create_audio('input/voice.wav')
        self.create_audio('output/instrumental.wav')
        runner = self.root / 'systemd-run'
        runner.write_text('#!/usr/bin/python3\nimport json,os,sys\n'
                          'open(os.environ["TEST_LOG"], "w").write(json.dumps(sys.argv[1:]))\n')
        runner.chmod(0o755)
        result = self.launch('preset', 'mix', 'voice.wav', 'instrumental.wav',
                             '--output', 'song.wav')
        self.assertEqual(result.returncode, 0, result.stderr)
        args = json.loads(self.log.read_text())
        self.assertIn('--user', args)
        self.assertEqual(args[-5:], ['mix', 'voice.wav', 'instrumental.wav',
                                    '--output', 'song.wav'])
        self.assertFalse((self.media / 'output/song.wav').exists())

    def test_mix_rejects_unsafe_paths_and_ambiguous_audio(self):
        self.create_audio('input/voice.wav')
        self.create_audio('output/instrumental.wav')
        for unsafe in ('../voice.wav', '/tmp/voice.wav', 'https://example.org/voice.wav'):
            result = self.launch('preset', 'mix', unsafe, 'instrumental.wav')
            self.assertNotEqual(result.returncode, 0)
        for unsafe in ('../song.wav', '/tmp/song.wav', 'song.mp3'):
            result = self.launch('preset', 'mix', 'voice.wav', 'instrumental.wav',
                                 '--output', unsafe)
            self.assertNotEqual(result.returncode, 0)
        (self.media / 'output/linked').symlink_to(self.media / 'input', target_is_directory=True)
        self.assertNotEqual(self.launch('preset', 'mix', 'linked/voice.wav',
                                       'instrumental.wav').returncode, 0)
        self.create_audio('output/voice.wav')
        self.assertNotEqual(self.launch('preset', 'mix', 'voice.wav',
                                       'instrumental.wav').returncode, 0)
        self.assertFalse(self.log.exists())

    def test_mix_rejects_missing_audio_stream(self):
        video = self.create_video()
        self.create_audio('output/instrumental.wav')
        result = self.run_preset(self.fake_media_launcher(), 'mix', video.name,
                                 'instrumental.wav')
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.media / 'output/video1-mix.wav').exists())

    def test_cli_has_no_network_or_host_home(self):
        result = self.launch('facefusion', 'cli', '--help')
        self.assertEqual(result.returncode, 0, result.stderr)
        args = json.loads(self.log.read_text())
        for flag in ('--network=none', '--pull=never', '--read-only',
                     '--security-opt=no-new-privileges', '--cap-drop=ALL'):
            self.assertIn(flag, args)
        self.assertIn(str(self.media / 'input') + ':/work/input:ro,Z', args)
        self.assertNotIn('--privileged', args)
        self.assertNotIn('--security-opt', args)
        self.assertNotIn('label=disable', args)

    def test_gui_exposes_only_wayland_socket(self):
        self.env.update(XDG_RUNTIME_DIR=str(self.root), WAYLAND_DISPLAY='wayland-0')
        with socket.socket(socket.AF_UNIX) as sock:
            sock.bind(str(self.root / 'wayland-0'))
            result = self.launch('rvc', '--foreground')
        self.assertEqual(result.returncode, 0, result.stderr)
        args = json.loads(self.log.read_text())
        self.assertIn('--network=none', args)
        self.assertIn(str(self.root / 'wayland-0') + ':/run/media/wayland-0:ro', args)
        self.assertIn('/run/media:rw,nosuid,nodev,size=1m,mode=1777', args)
        self.assertFalse(any('uid=' in arg or 'gid=' in arg for arg in args))
        self.assertNotIn('--publish', args)
        self.assertFalse(any('dbus' in arg for arg in args))

    def test_rvc_cli_is_offline_and_mounts_only_preset_code(self):
        result = self.launch('rvc', 'cli', '/work/output/job/audio.wav', '/work/output/job')
        self.assertEqual(result.returncode, 0, result.stderr)
        args = json.loads(self.log.read_text())
        self.assertIn('--network=none', args)
        self.assertIn('--entrypoint', args)
        self.assertIn('python', args)
        self.assertIn(str(self.root / 'preset_rvc.py') + ':/opt/preset_rvc.py:ro,Z', args)
        self.assertIn('/opt/preset_rvc.py', args)
        self.assertNotIn('label=disable', args)

    def test_voice_preset_dispatches_to_user_service(self):
        (self.media / 'input/video1.mp4').write_bytes(b'not processed in dispatch')
        runner = self.root / 'systemd-run'
        runner.write_text('#!/usr/bin/python3\nimport json,os,sys\n'
                          'open(os.environ["TEST_LOG"], "w").write(json.dumps(sys.argv[1:]))\n')
        runner.chmod(0o755)
        result = self.launch('preset', 'audio-convert', 'video1.mp4')
        self.assertEqual(result.returncode, 0, result.stderr)
        args = json.loads(self.log.read_text())
        self.assertIn('--user', args)
        self.assertIn('--property=Restart=no', args)
        self.assertIn('audio-convert', args)
        self.assertIn('video1.mp4', args)

    def test_face_preset_requires_all_sources(self):
        (self.media / 'input/video1.mp4').write_bytes(b'video')
        self.assertNotEqual(self.launch('preset', 'video-convert', 'video1.mp4').returncode, 0)
        self.assertFalse(self.log.exists())

    def test_complete_preset_rejects_local_url(self):
        result = self.launch('preset', 'convert', 'file:///tmp/video.mp4')
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.log.exists())

    def test_old_preset_names_are_rejected(self):
        for name in ('voce', 'volti', 'unisci', 'completo'):
            with self.subTest(name=name):
                self.assertEqual(self.launch('preset', name, 'video1.mp4').returncode, 2)

    def test_all_url_presets_dispatch_one_background_job(self):
        for number in range(11, 19):
            (self.media / f'input/source{number}.jpg').write_bytes(b'source')
        runner = self.root / 'systemd-run'
        runner.write_text('#!/usr/bin/python3\nimport json,os,sys\n'
                          'open(os.environ["TEST_LOG"], "w").write(json.dumps(sys.argv[1:]))\n')
        runner.chmod(0o755)
        (self.media / 'input/audio.wav').write_bytes(b'audio')
        for preset in ('audio-convert', 'video-convert', 'merge', 'split',
                       'split-stems', 'convert'):
            with self.subTest(preset=preset):
                extra = ['audio.wav'] if preset == 'merge' else []
                result = self.launch('preset', preset, 'https://example.org/video', *extra)
                self.assertEqual(result.returncode, 0, result.stderr)
                args = json.loads(self.log.read_text())
                self.assertIn('--user', args)
                self.assertIn(preset, args)
                self.assertIn('https://example.org/video', args)
                if extra:
                    self.assertEqual(args[-1], 'audio.wav')
                self.assertFalse(list((self.media / 'input').glob('download-*')))

    def test_mux_preset_rejects_ambiguous_audio(self):
        (self.media / 'input/video1.mp4').write_bytes(b'video')
        (self.media / 'input/audio.wav').write_bytes(b'audio')
        (self.media / 'output/audio.wav').write_bytes(b'audio')
        self.assertNotEqual(self.launch('preset', 'merge', 'video1.mp4', 'audio.wav').returncode, 0)
        self.assertFalse(self.log.exists())

    def test_mux_preset_creates_audio_video_with_streams(self):
        if subprocess.run(['bash', '-c', 'command -v ffmpeg && command -v ffprobe'],
                          capture_output=True).returncode != 0:
            self.skipTest('ffmpeg and ffprobe required')
        self.create_video()
        audio = self.media / 'input/audio.wav'
        subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-f', 'lavfi',
                        '-i', 'sine=frequency=440:duration=1', str(audio)], check=True)
        result = self.run_preset(self.fake_media_launcher(), 'merge', 'video1.mp4', 'audio.wav')
        self.assertEqual(result.returncode, 0, result.stderr)
        output = self.media / 'output/video1-unito.mp4'
        self.assertTrue(output.is_file())
        self.assertEqual(self.stream_types(output), {'video', 'audio'})

    def test_voice_preset_outputs_audio_only(self):
        self.create_video(audio=True)
        result = self.run_preset(self.fake_media_launcher(), 'audio-convert', 'video1.mp4')
        self.assertEqual(result.returncode, 0, result.stderr)
        output = self.media / 'output/video1-mia_voce.wav'
        self.assertEqual(self.stream_types(output), {'audio'})
        self.assertFalse((self.media / 'output/video1-mia_voce.mp4').exists())

    def test_split_presets_output_separate_streams_without_conversion(self):
        original = self.create_video(audio=True).read_bytes()
        for preset in ('split', 'split-stems'):
            with self.subTest(preset=preset):
                result = self.run_preset(self.fake_media_launcher(), preset, 'video1.mp4')
                self.assertEqual(result.returncode, 0, result.stderr)
                output = self.media / 'output' / f'video1-{preset}'
                expected = {'video.mp4', 'audio.wav'}
                if preset == 'split-stems':
                    expected |= {'vocals.wav', 'instrumental.wav'}
                    args = json.loads((self.media / 'rvc-args.json').read_text())
                    self.assertIn('--separate-only', args)
                else:
                    self.assertFalse((self.media / 'rvc-args.json').exists())
                self.assertEqual({p.name for p in output.iterdir()}, expected)
                for name in expected:
                    self.assertEqual(self.stream_types(output / name),
                                     {'video'} if name == 'video.mp4' else {'audio'})
                self.assertEqual((self.media / 'input/video1.mp4').read_bytes(), original)
                self.assertFalse(list((self.media / 'output').rglob('*mia_voce*')))
                before = {p.name: p.read_bytes() for p in output.iterdir()}
                repeated = self.run_preset(self.fake_media_launcher(), preset, 'video1.mp4',
                                           job_id='repeat')
                self.assertNotEqual(repeated.returncode, 0)
                self.assertEqual({p.name: p.read_bytes() for p in output.iterdir()}, before)

    def test_split_presets_reject_video_without_audio(self):
        self.create_video()
        for preset in ('split', 'split-stems'):
            result = self.run_preset(self.fake_media_launcher(), preset, 'video1.mp4')
            self.assertNotEqual(result.returncode, 0)
        self.assertFalse(list((self.media / 'output').iterdir()))

    def test_face_preset_preserves_audio_only_when_present(self):
        for audio in (False, True):
            with self.subTest(audio=audio):
                video = self.media / 'input/video1.mp4'
                if video.exists():
                    video.unlink()
                self.create_video(audio=audio)
                for number in range(11, 19):
                    (self.media / f'input/source{number}.jpg').write_bytes(b'source')
                output = self.media / 'output/video1-facefusion.mp4'
                if output.exists():
                    output.unlink()
                result = self.run_preset(self.fake_media_launcher(), 'video-convert', 'video1.mp4',
                                         job_id=f'test-{audio}')
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(self.stream_types(output),
                                 {'video', 'audio'} if audio else {'video'})

    def test_face_preset_uses_requested_options(self):
        self.create_video(audio=True)
        for number in range(11, 19):
            (self.media / f'input/source{number}.jpg').write_bytes(b'source')
        result = self.run_preset(self.fake_media_launcher(), 'video-convert', 'video1.mp4')
        self.assertEqual(result.returncode, 0, result.stderr)
        args = json.loads((self.media / 'facefusion-args.json').read_text())
        source_start = args.index('--source-paths') + 1
        self.assertEqual(args[source_start:source_start + 8],
                         [f'/work/input/source{number}.jpg' for number in range(11, 19)])
        expected = {
            '--processors': ['face_swapper'],
            '--face-swapper-model': ['hyperswap_1a_256'],
            '--face-swapper-pixel-boost': ['256x256'],
            '--face-swapper-weight': ['0.5'],
            '--face-detector-model': ['yolo_face'],
            '--face-detector-size': ['640x640'],
            '--face-detector-angles': ['0', '90', '180', '270'],
            '--face-detector-score': ['0.5'],
            '--face-selector-mode': ['one'],
            '--face-selector-order': ['large-small'],
            '--face-selector-gender': ['female'],
            '--face-selector-race': ['white'],
            '--face-mask-types': ['occlusion', 'region', 'area', 'box'],
            '--face-occluder-model': ['xseg_1'],
            '--face-parser-model': ['bisenet_resnet_34'],
            '--face-mask-blur': ['0.3'],
            '--output-video-encoder': ['libx264'],
            '--output-video-preset': ['veryfast'],
            '--output-video-quality': ['80'],
            '--output-video-fps': ['30'],
            '--execution-providers': ['cpu'],
            '--output-audio-encoder': ['aac'],
            '--jobs-path': ['/work/state'],
            '--temp-path': ['/work/state/tmp'],
        }
        for flag, values in expected.items():
            with self.subTest(flag=flag):
                start = args.index(flag) + 1
                self.assertEqual(args[start:start + len(values)], values)

    def test_complete_preset_downloads_and_combines_both_results(self):
        fixture = self.create_video(audio=True)
        for number in range(11, 19):
            (self.media / f'input/source{number}.jpg').write_bytes(b'source')
        self.fake_downloader(fixture)
        result = self.run_preset(self.fake_media_launcher(), 'convert',
                                 'https://example.org/video', job_id='test')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.media / 'input/download-test.mp4').is_file())
        self.assertEqual(self.stream_types(self.media / 'output/download-test-mia_voce.wav'),
                         {'audio'})
        self.assertEqual(self.stream_types(self.media / 'output/download-test-facefusion.mp4'),
                         {'video', 'audio'})
        self.assertEqual(self.stream_types(self.media / 'output/download-test-completo.mp4'),
                         {'video', 'audio'})
        face_args = json.loads((self.media / 'facefusion-args.json').read_text())
        self.assertEqual(face_args[face_args.index('--face-selector-gender') + 1], 'female')
        self.assertEqual(face_args[face_args.index('--output-video-fps') + 1], '30')
        downloader_args = json.loads(self.log.read_text())
        self.assertIn('--ignore-config', downloader_args)
        self.assertIn('--no-playlist', downloader_args)

    def test_default_gui_uses_independent_user_service(self):
        self.env.update(XDG_RUNTIME_DIR=str(self.root), WAYLAND_DISPLAY='wayland-0')
        runner = self.root / 'systemd-run'
        runner.write_text('#!/usr/bin/python3\nimport json,os,sys\n'
                          'open(os.environ["TEST_LOG"], "w").write(json.dumps(sys.argv[1:]))\n')
        runner.chmod(0o755)
        with socket.socket(socket.AF_UNIX) as sock:
            sock.bind(str(self.root / 'wayland-0'))
            result = self.launch('rvc')
        self.assertEqual(result.returncode, 0, result.stderr)
        args = json.loads(self.log.read_text())
        self.assertIn('--user', args)
        self.assertIn('--unit=ai-media-rvc', args)
        self.assertIn('--property=Restart=no', args)
        self.assertIn('--foreground', args)
        self.assertNotIn('--scope', args)
        self.assertNotIn('--pty', args)
        self.assertNotIn('--wait', args)

    def test_all_presets_download_url_before_processing(self):
        fixture = self.create_video(audio=True)
        self.fake_downloader(fixture)
        for number in range(11, 19):
            (self.media / f'input/source{number}.jpg').write_bytes(b'source')
        audio = self.media / 'input/audio.wav'
        subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-i',
                        str(fixture), '-vn', str(audio)], check=True)
        outputs = {
            'audio-convert': 'mia_voce.wav', 'video-convert': 'facefusion.mp4',
            'merge': 'unito.mp4', 'split': 'split', 'split-stems': 'split-stems',
            'convert': 'completo.mp4',
        }
        for preset, suffix in outputs.items():
            with self.subTest(preset=preset):
                extra = ['audio.wav'] if preset == 'merge' else []
                result = self.run_preset(self.fake_media_launcher(), preset,
                                         'https://example.org/video?a=1&b=2', *extra,
                                         job_id=preset)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout.count('Downloading one video'), 1)
                self.assertTrue((self.media / f'input/download-{preset}.mp4').is_file())
                output = self.media / f'output/download-{preset}-{suffix}'
                self.assertTrue(output.exists())
                if preset in ('split', 'split-stems'):
                    self.assertEqual(self.stream_types(output / 'video.mp4'), {'video'})
                    self.assertEqual(self.stream_types(output / 'audio.wav'), {'audio'})
                else:
                    self.assertEqual(self.stream_types(output), {'audio'} if
                                     preset == 'audio-convert' else {'video', 'audio'})
                download_args = json.loads(self.log.read_text())
                self.assertEqual(download_args[-1], 'https://example.org/video?a=1&b=2')
                for flag in ('--ignore-config', '--no-playlist', '--no-overwrites'):
                    self.assertIn(flag, download_args)

    def test_convert_also_accepts_local_video_without_download(self):
        fixture = self.create_video(audio=True)
        self.fake_downloader(fixture)
        for number in range(11, 19):
            (self.media / f'input/source{number}.jpg').write_bytes(b'source')
        result = self.run_preset(self.fake_media_launcher(), 'convert', fixture.name)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.log.exists())
        self.assertEqual(self.stream_types(self.media / 'output/video1-completo.mp4'),
                         {'video', 'audio'})

    def test_all_presets_reject_invalid_urls_before_dispatch(self):
        for preset in ('split', 'split-stems', 'audio-convert', 'video-convert',
                       'merge', 'convert'):
            for url in ('file:///tmp/video.mp4', 'https://localhost/video',
                        'http://192.168.1.1/video', 'https://user:password@example.org/video'):
                with self.subTest(preset=preset, url=url):
                    extra = ['audio.wav'] if preset == 'merge' else []
                    result = self.launch('preset', preset, url, *extra)
                    self.assertNotEqual(result.returncode, 0)
                    self.assertFalse(self.log.exists())

    def test_failed_url_download_does_not_start_processing(self):
        downloader = self.root / 'yt-dlp'
        downloader.write_text('#!/bin/sh\nexit 1\n')
        downloader.chmod(0o755)
        result = self.run_preset(self.fake_media_launcher(), 'split',
                                 'https://example.org/video')
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(list((self.media / 'output').iterdir()))

    def test_symlinked_input_is_rejected(self):
        (self.media / 'input').rmdir()
        (self.media / 'input').symlink_to(self.root)
        self.assertNotEqual(self.launch('facefusion', 'cli', '--help').returncode, 0)
        self.assertFalse(self.log.exists())

    def test_synced_storage_is_rejected(self):
        directory = self.root / '.config/Nextcloud'
        directory.mkdir(parents=True)
        (directory / 'nextcloud.cfg').write_text(
            '[Accounts]\n0\\Folders\\1\\localPath=' + str(self.media) + '\n'
        )
        self.assertNotEqual(self.launch('facefusion', 'cli', '--help').returncode, 0)
        self.assertFalse(self.log.exists())

    def test_invalid_tool_is_rejected(self):
        self.assertEqual(self.launch('--network=host').returncode, 2)
        self.assertFalse(self.log.exists())


if __name__ == '__main__':
    unittest.main()
