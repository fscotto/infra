"""Offline RVC worker for the voice preset (runs inside the RVC container)."""

import argparse
import os
from pathlib import Path
import sys


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("input_wav", type=Path)
    parser.add_argument("job_dir", type=Path)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--separate-only", action="store_true")
    mode.add_argument("--convert-only", action="store_true")
    args = parser.parse_args()
    source = args.input_wav.resolve(strict=True)
    job = args.job_dir.resolve(strict=True)
    output = Path("/work/output").resolve(strict=True)
    if not source.is_relative_to(output) or not job.is_relative_to(output):
        raise ValueError("RVC preset paths must be inside /work/output")
    if source.parent != job or not source.is_file():
        raise ValueError("Expected the extracted WAV inside the job directory")

    weights = Path("/work/state/weights/mia_voce.pth")
    index = Path("/work/state/mia_voce/added_IVF256_Flat_nprobe_1_mia_voce_v2.index")
    if not args.separate_only and not weights.is_file():
        raise FileNotFoundError(weights)
    if not args.separate_only and not index.is_file():
        raise FileNotFoundError(index)
    os.environ.update(
        weight_root="/work/state/weights",
        outside_index_root="/work/models/indices",
        index_root="/work/state",
        weight_pymss_root="/opt/app/assets/pymss_weights",
        rmvpe_root="/opt/app/assets/rmvpe",
        OMP_NUM_THREADS="4",
        MKL_NUM_THREADS="4",
    )

    # The pinned WebUI imports its own argparse configuration at module load.
    sys.argv = sys.argv[:1]
    vocal_source = source
    if not args.convert_only:
        from tools.pymss_webui import pymss_separate

        vocals_dir = job / "vocals"
        instrumental_dir = job / "instrumental"
        vocals_dir.mkdir()
        instrumental_dir.mkdir()
        failures = []

        def on_event(event):
            if event.get("event") in ("fatal", "cancelled", "busy"):
                failures.append(event.get("message", str(event)))

        for progress in pymss_separate(
            "vocals-bs-roformer-368", str(source), str(vocals_dir), None,
            str(instrumental_dir), "wav", event_callback=on_event,
        ):
            print(progress, flush=True)
        if failures:
            raise RuntimeError("RVC separation failed: " + "; ".join(failures))
        vocals = list(vocals_dir.glob("*.wav"))
        instrumental = list(instrumental_dir.glob("*.wav"))
        if len(vocals) != 1 or len(instrumental) != 1:
            raise RuntimeError("RVC did not produce exactly one vocal and instrumental stem")

        if args.separate_only:
            print("Vocal and instrumental stems ready (no voice conversion)", flush=True)
            return

        vocal_source = vocals[0]

    from configs.config import Config
    from infer.vc.modules import VC
    import soundfile as sf

    voice = VC(Config())
    voice.get_vc(weights.name)
    status, result = voice.vc_single(
        0, str(vocal_source), 0, "rmvpe", str(index), 0.75, 0, 1, 0.33,
    )
    if result is None or result[0] is None or result[1] is None:
        raise RuntimeError("RVC voice conversion failed: " + str(status))
    converted = job / "vocals-mia_voce.wav"
    sf.write(converted, result[1], result[0])
    if converted.stat().st_size == 0:
        raise RuntimeError("RVC produced an empty converted voice")
    print("RVC converted voice ready", flush=True)


if __name__ == "__main__":
    main()
