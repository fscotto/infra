"""Small host-side orchestrator for offline ai-media presets."""

import argparse
from datetime import datetime
import ipaddress
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
from urllib.parse import urlsplit
import uuid


NAME = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]*\Z")
SOURCE_NAMES = tuple(f"source{number}.jpg" for number in range(11, 19))


def video_url(value):
    parsed = urlsplit(value)
    if parsed.scheme not in ("http", "https") or not parsed.hostname or parsed.username or parsed.password:
        raise ValueError("Use an HTTP(S) video URL without embedded credentials")
    host = parsed.hostname.lower().rstrip(".")
    if host == "localhost" or host.endswith(".localhost"):
        raise ValueError("Local URLs are not accepted")
    try:
        address = ipaddress.ip_address(host)
    except ValueError:
        pass
    else:
        if not address.is_global:
            raise ValueError("Private or local IP URLs are not accepted")
    return value


def media_file(root, name, *, video=False):
    if not NAME.fullmatch(name) or name in (".", ".."):
        raise ValueError("Use a simple filename in the ai-media input directory")
    path = root / "input" / name
    if not path.is_file() or path.is_symlink():
        raise FileNotFoundError(path)
    if video and path.suffix.lower() != ".mp4":
        raise ValueError("The video must be an MP4 file")
    return path


def audio_file(root, name):
    if not name or any(not NAME.fullmatch(part) or part in (".", "..")
                       for part in name.split("/")):
        raise ValueError("Use an audio path relative to input/ or output/ without traversal")
    matches = [root / directory / name for directory in ("input", "output")]
    matches = [path for path in matches if path.is_file() and path.resolve() == path]
    if len(matches) != 1:
        raise ValueError("Audio must exist in exactly one of input/ or output/")
    return matches[0]


def container_path(root, path):
    directory = path.relative_to(root).parts[0]
    if directory not in ("input", "output"):
        raise ValueError("Media path outside input/output")
    return "/work/" + str(path.relative_to(root))


def run(*command):
    print("+", " ".join(map(str, command)), flush=True)
    subprocess.run([str(part) for part in command], check=True)


def has_stream(path, kind):
    result = subprocess.run([
        "ffprobe", "-v", "error", "-show_entries", "stream=codec_type",
        "-of", "json", str(path),
    ], check=True, capture_output=True, text=True)
    return kind in [stream["codec_type"] for stream in json.loads(result.stdout)["streams"]]


def probe(path, kind):
    if not has_stream(path, kind):
        raise RuntimeError(f"Missing {kind} stream: {path}")


def duration(path):
    result = subprocess.run([
        "ffprobe", "-v", "error", "-show_entries", "format=duration",
        "-of", "default=noprint_wrappers=1:nokey=1", str(path),
    ], check=True, capture_output=True, text=True)
    return float(result.stdout.strip())


def output_path(root, video, suffix, extension="mp4"):
    return root / "output" / f"{video.stem}-{suffix}.{extension}"


def mix_target(root, args):
    name = args.output or f"{Path(args.vocals).stem}-mix.wav"
    return wav_target(root, name)


def wav_target(root, name):
    if not NAME.fullmatch(name) or Path(name).suffix.lower() != ".wav":
        raise ValueError("Use a simple WAV output filename")
    target = root / "output" / name
    if target.exists() or target.is_symlink():
        raise FileExistsError(target)
    return target


def process_voice(args, root, launcher):
    source = audio_file(root, args.audio)
    probe(source, "audio")
    target = wav_target(root, args.output or f"{source.stem}-mia_voce.wav")
    job = root / "output" / f".{source.stem}-voice-convert-{args.job_id}"
    job.mkdir(mode=0o700)
    print("Working directory:", job, flush=True)
    prepared = job / "audio.wav"
    run(launcher, "ffmpeg", "-hide_banner", "-loglevel", "error", "-n",
        "-i", container_path(root, source), "-map", "0:a:0", "-vn",
        "-c:a", "pcm_s16le", container_path(root, prepared))
    run(launcher, "rvc", "cli", container_path(root, prepared),
        container_path(root, job), "--convert-only")
    converted = job / "vocals-mia_voce.wav"
    probe(converted, "audio")
    os.link(converted, target)
    return target


def process_mix(args, root, launcher):
    vocals = audio_file(root, args.vocals)
    instrumental = audio_file(root, args.instrumental)
    target = mix_target(root, args)
    for source in (vocals, instrumental):
        probe(source, "audio")
    run(launcher, "ffmpeg", "-hide_banner", "-loglevel", "error", "-n",
        "-i", container_path(root, vocals), "-i", container_path(root, instrumental),
        "-filter_complex", "[0:a][1:a]amix=inputs=2:duration=longest:normalize=0[a]",
        "-map", "[a]", "-c:a", "pcm_s16le", container_path(root, target))
    probe(target, "audio")
    return target


def mux(launcher, root, video, audio, target):
    run(launcher, "ffmpeg", "-hide_banner", "-loglevel", "error", "-n",
        "-i", container_path(root, video), "-i", container_path(root, audio),
        "-map", "0:v:0", "-map", "1:a:0", "-c:v", "copy", "-c:a", "aac",
        "-b:a", "192k", "-shortest", "-movflags", "+faststart",
        container_path(root, target))
    probe(target, "video")
    probe(target, "audio")


def download_video(root, url, job_id):
    video_url(url)
    if not job_id or not NAME.fullmatch(job_id):
        raise ValueError("Invalid job ID")
    if shutil.which("yt-dlp") is None:
        raise RuntimeError("yt-dlp is required for URL downloads")
    prefix = f"download-{job_id}"
    destination = root / "input" / f"{prefix}.mp4"
    if list((root / "input").glob(prefix + ".*")):
        raise FileExistsError(destination)
    print("Downloading one video into input/ with yt-dlp", flush=True)
    subprocess.run([
        "yt-dlp", "--ignore-config", "--no-playlist", "--no-overwrites",
        "--no-progress", "-t", "mp4", "--recode-video", "mp4",
        "--output", str(root / "input" / f"{prefix}.%(ext)s"), url,
    ], check=True)
    if not destination.is_file() or destination.is_symlink():
        raise RuntimeError("yt-dlp did not produce the expected MP4 in input/")
    probe(destination, "video")
    return destination


def process_split(args, root, launcher, video):
    probe(video, "audio")
    target = root / "output" / f"{video.stem}-{args.preset}"
    if target.exists():
        raise FileExistsError(target)
    job = root / "output" / f".{video.stem}-{args.preset}-{args.job_id}"
    job.mkdir(mode=0o700)
    print("Working directory:", job, flush=True)
    silent = job / "video.mp4"
    audio = job / "audio.wav"
    run(launcher, "ffmpeg", "-hide_banner", "-loglevel", "error", "-n",
        "-i", container_path(root, video), "-map", "0:v:0", "-c:v", "copy",
        "-an", "-movflags", "+faststart", container_path(root, silent))
    probe(silent, "video")
    if has_stream(silent, "audio"):
        raise RuntimeError("Unexpected audio stream in split video")
    run(launcher, "ffmpeg", "-hide_banner", "-loglevel", "error", "-n",
        "-i", container_path(root, video), "-map", "0:a:0", "-vn",
        "-c:a", "pcm_s16le", container_path(root, audio))
    probe(audio, "audio")
    files = {"video.mp4": silent, "audio.wav": audio}
    if args.preset == "split-stems":
        run(launcher, "rvc", "cli", container_path(root, audio),
            container_path(root, job), "--separate-only")
        for stem in ("vocals", "instrumental"):
            matches = list((job / stem).glob("*.wav"))
            if len(matches) != 1:
                raise RuntimeError(f"Expected exactly one {stem} stem")
            probe(matches[0], "audio")
            files[f"{stem}.wav"] = matches[0]
    # Publish only after every processing step and stream check succeeded.
    target.mkdir(mode=0o700)
    for name, source in files.items():
        os.link(source, target / name)
    return target


def process(args, root, launcher):
    video = media_file(root, args.video, video=True)
    probe(video, "video")
    if args.preset in ("split", "split-stems"):
        return process_split(args, root, launcher, video)
    if args.preset == "merge":
        audio = audio_file(root, args.audio)
        probe(audio, "audio")
        target = output_path(root, video, "unito")
        if target.exists():
            raise FileExistsError(target)
        mux(launcher, root, video, audio, target)
        return target

    suffix = "mia_voce" if args.preset == "audio-convert" else "facefusion"
    target = output_path(root, video, suffix, "wav" if args.preset == "audio-convert" else "mp4")
    if target.exists():
        raise FileExistsError(target)
    job = root / "output" / f".{video.stem}-{suffix}-{args.job_id}"
    job.mkdir(mode=0o700)
    print("Working directory:", job, flush=True)
    if args.preset == "audio-convert":
        probe(video, "audio")
        extracted = job / "audio.wav"
        run(launcher, "ffmpeg", "-hide_banner", "-loglevel", "error", "-n",
            "-i", container_path(root, video), "-vn", "-c:a", "pcm_s16le",
            container_path(root, extracted))
        run(launcher, "rvc", "cli", container_path(root, extracted), container_path(root, job))
        instrumental = list((job / "instrumental").glob("*.wav"))
        if len(instrumental) != 1:
            raise RuntimeError("Expected exactly one instrumental stem")
        converted = job / "vocals-mia_voce.wav"
        probe(converted, "audio")
        mixed = job / "mix.wav"
        run(launcher, "ffmpeg", "-hide_banner", "-loglevel", "error", "-n",
            "-i", container_path(root, instrumental[0]),
            "-i", container_path(root, converted),
            "-filter_complex", "[0:a][1:a]amix=inputs=2:duration=longest:normalize=0[a]",
            "-map", "[a]", "-c:a", "pcm_s16le", container_path(root, mixed))
        probe(mixed, "audio")
        os.link(mixed, target)
    else:
        original_has_audio = has_stream(video, "audio")
        sources = [media_file(root, name) for name in SOURCE_NAMES]
        processed = job / "swapped.mp4"
        run(launcher, "facefusion", "cli", "headless-run",
            "--source-paths", *[container_path(root, path) for path in sources],
            "--target-path", container_path(root, video),
            "--output-path", container_path(root, processed),
            "--processors", "face_swapper", "--face-swapper-model", "hyperswap_1a_256",
            "--face-swapper-pixel-boost", "256x256", "--face-swapper-weight", "0.5",
            "--face-detector-model", "yolo_face", "--face-detector-size", "640x640",
            "--face-detector-angles", "0", "90", "180", "270",
            "--face-detector-score", "0.5", "--face-selector-mode", "one",
            "--face-selector-order", "large-small", "--face-selector-gender", "female",
            "--face-selector-race", "white",
            "--face-mask-types", "occlusion", "region", "area", "box",
            "--face-occluder-model", "xseg_1",
            "--face-parser-model", "bisenet_resnet_34", "--face-mask-blur", "0.3",
            "--output-video-encoder", "libx264", "--output-video-preset", "veryfast",
            "--output-video-quality", "80", "--output-video-fps", "30",
            "--execution-providers", "cpu", "--output-audio-encoder", "aac",
            "--jobs-path", "/work/state", "--temp-path", "/work/state/tmp")
        probe(processed, "video")
        if abs(duration(processed) - duration(video)) > 0.5:
            raise RuntimeError("FaceFusion output duration differs from the input; refusing a partial result")
        if original_has_audio:
            # Restore the original soundtrack explicitly. Some completed
            # FaceFusion jobs have produced video-only MP4 files.
            mux(launcher, root, processed, video, target)
        else:
            run(launcher, "ffmpeg", "-hide_banner", "-loglevel", "error", "-n",
                "-i", container_path(root, processed), "-map", "0:v:0",
                "-c:v", "copy", "-an", "-movflags", "+faststart",
                container_path(root, target))
            probe(target, "video")
            if has_stream(target, "audio"):
                raise RuntimeError("Unexpected audio stream in silent FaceFusion output")
    return target


def process_complete(args, root, launcher):
    video = media_file(root, args.video, video=True)
    if not has_stream(video, "audio"):
        raise RuntimeError("The video has no audio to convert")
    common = {"video": video.name, "job_id": args.job_id}
    audio = process(argparse.Namespace(preset="audio-convert", **common), root, launcher)
    swapped = process(argparse.Namespace(preset="video-convert", **common), root, launcher)
    target = output_path(root, video, "completo")
    if target.exists():
        raise FileExistsError(target)
    mux(launcher, root, swapped, audio, target)
    return target


def main():
    parser = argparse.ArgumentParser(prog="ai-media preset")
    parser.add_argument("root", type=Path, help=argparse.SUPPRESS)
    parser.add_argument("launcher", type=Path, help=argparse.SUPPRESS)
    parser.add_argument("--run", action="store_true", help=argparse.SUPPRESS)
    parser.add_argument("--job-id", help=argparse.SUPPRESS)
    sub = parser.add_subparsers(dest="preset", required=True)
    for name in ("audio-convert", "video-convert", "merge", "split", "split-stems", "convert"):
        command = sub.add_parser(name)
        command.add_argument("video", help="MP4 filename inside input/ or HTTP(S) video URL")
        if name == "merge":
            command.add_argument("audio", help="unique audio filename in input/ or output/")
    mix = sub.add_parser("mix", help="mix vocal and instrumental audio into one WAV")
    mix.add_argument("vocals", help="vocal audio path relative to input/ or output/")
    mix.add_argument("instrumental", help="instrumental audio path relative to input/ or output/")
    mix.add_argument("--output", help="WAV filename in output/ (default: <vocals>-mix.wav)")
    voice = sub.add_parser("voice-convert", help="apply mia_voce directly to an audio file")
    voice.add_argument("audio", help="audio path relative to input/ or output/")
    voice.add_argument("--output", help="WAV filename in output/ (default: <audio>-mia_voce.wav)")
    args = parser.parse_args()
    root = args.root.resolve(strict=True)
    launcher = args.launcher.resolve(strict=True)
    audio_only = args.preset in ("mix", "voice-convert")
    remote_video = not audio_only and not NAME.fullmatch(args.video)
    if args.preset == "voice-convert":
        source = audio_file(root, args.audio)
        wav_target(root, args.output or f"{source.stem}-mia_voce.wav")
        preset_inputs = [args.audio]
        if args.output:
            preset_inputs += ["--output", args.output]
    elif args.preset == "mix":
        audio_file(root, args.vocals)
        audio_file(root, args.instrumental)
        mix_target(root, args)
        preset_inputs = [args.vocals, args.instrumental]
        if args.output:
            preset_inputs += ["--output", args.output]
    elif remote_video:
        video_url(args.video)
        if shutil.which("yt-dlp") is None:
            raise RuntimeError("yt-dlp is required for URL downloads")
    else:
        media_file(root, args.video, video=True)
    if not audio_only:
        preset_inputs = [args.video] + ([args.audio] if args.preset == "merge" else [])
    if args.preset == "merge":
        audio_file(root, args.audio)
    if args.preset in ("video-convert", "convert"):
        for name in SOURCE_NAMES:
            media_file(root, name)
    if args.run:
        if remote_video:
            args.video = download_video(root, args.video, args.job_id).name
        if args.preset == "voice-convert":
            result = process_voice(args, root, launcher)
        elif args.preset == "mix":
            result = process_mix(args, root, launcher)
        else:
            result = (process_complete(args, root, launcher)
                      if args.preset == "convert" else process(args, root, launcher))
        print("Completed:", result, flush=True)
        return
    unit = "ai-media-preset-" + datetime.now().strftime("%Y%m%d-%H%M%S") + "-" + uuid.uuid4().hex[:8]
    subprocess.run(["systemd-run", "--user", "--collect", f"--unit={unit}",
        "--property=Type=exec", "--property=Restart=no",
        "/usr/bin/python3", str(Path(__file__).resolve()), str(root), str(launcher),
        "--run", "--job-id", unit, args.preset,
        *preset_inputs], check=True)
    print("Job:", unit)
    print("Logs: journalctl --user -fu", unit)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, FileNotFoundError, FileExistsError, subprocess.CalledProcessError) as error:
        raise SystemExit(str(error)) from error
