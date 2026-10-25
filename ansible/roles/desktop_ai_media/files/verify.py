import os
import gc
import pathlib
import socket
import subprocess
import sys
import tempfile

interfaces = {p.name for p in pathlib.Path("/sys/class/net").iterdir()}
assert interfaces == {"lo"}, interfaces
for family, address in (
    (socket.AF_INET, ("1.1.1.1", 443)),
    (socket.AF_INET6, ("2606:4700:4700::1111", 443, 0, 0)),
):
    with socket.socket(family, socket.SOCK_STREAM) as connection:
        connection.settimeout(2)
        try:
            connection.connect(address)
        except OSError:
            pass
        else:
            raise RuntimeError("External networking is available")
subprocess.run(["sha256sum", "--quiet", "--check", "/opt/model-checksums.sha256"], check=True)
if os.environ["APP"] == "facefusion":
    sys.path.insert(0, "/opt/app")
    from facefusion import state_manager
    from facefusion.args import apply_args
    from facefusion.program import create_program
    from facefusion.core import common_pre_check, processors_pre_check
    args = vars(create_program().parse_args([
        "run", "--execution-providers", "cpu", "--processors", "face_swapper",
    ]))
    apply_args(args, state_manager.init_item)
    assert common_pre_check() and processors_pre_check()
    import numpy as np
    import onnxruntime as ort
    options = ort.SessionOptions()
    options.intra_op_num_threads = 4
    options.inter_op_num_threads = 1
    model = ort.InferenceSession(
        "/opt/app/.assets/models/hyperswap_1a_256.onnx",
        sess_options=options, providers=["CPUExecutionProvider"],
    )
    feeds = {}
    for argument in model.get_inputs():
        assert argument.type == "tensor(float)"
        shape = [size if isinstance(size, int) and size > 0 else 1 for size in argument.shape]
        feeds[argument.name] = np.full(shape, 0.01, dtype=np.float32)
    assert all(np.isfinite(result).all() for result in model.run(None, feeds))
else:
    sys.path.insert(0, "/opt/app")
    import numpy as np
    import torch
    import transformers
    import onnxruntime
    assert not torch.cuda.is_available()
    torch.set_num_threads(4)
    from infer.hubert import load_hubert_model, extract_hubert_features
    from infer.rmvpe import RMVPE
    with torch.inference_mode():
        hubert = load_hubert_model("cpu", False)
        features = extract_hubert_features(hubert, torch.zeros(1, 16000), "v2")
        assert torch.isfinite(features).all()
        del hubert, features
        pitch = RMVPE("/opt/app/assets/rmvpe/rmvpe.pt", False, "cpu")
        result = pitch.infer_from_audio(np.zeros(16000, dtype=np.float32))
        assert len(result) > 0 and np.isfinite(result).all()
        del pitch
    gc.collect()
    # Exercise the exact WebUI subprocess entrypoint, not only in-process imports.
    from scipy.io import wavfile
    with tempfile.TemporaryDirectory(prefix="rvc-slicing-") as temporary:
        directory = pathlib.Path(temporary)
        dataset = directory / "input"
        experiment = directory / "experiment"
        dataset.mkdir()
        experiment.mkdir()
        samples = np.arange(4 * 40000, dtype=np.float32) / 40000
        waveform = (0.2 * np.sin(2 * np.pi * 220 * samples)).astype(np.float32)
        wavfile.write(dataset / "synthetic.wav", 40000, waveform)
        subprocess.run([
            sys.executable, "train/preprocess.py", str(dataset), "40000", "1",
            str(experiment), "False", "3.7",
        ], check=True, timeout=120)
        assert list((experiment / "0_gt_wavs").glob("*.wav"))
        assert list((experiment / "1_16k_wavs").glob("*.wav"))
    print("rvc: synthetic data slicing subprocess verified", flush=True)
    # Check the v2/40k training baseline and writable inference-model export.
    from train.utils import get_hparams_from_file
    from train.process_ckpt import savee
    hps = get_hparams_from_file("configs/v1/40k.json")
    checkpoint = torch.load("assets/pretrained_v2/f0G40k.pth", map_location="cpu")
    assert checkpoint["model"]
    pathlib.Path("/work/state/weights").mkdir(exist_ok=True)
    savee(checkpoint["model"], "40k", 1, "offline-readiness", 0, "v2", hps)
    exported = pathlib.Path("assets/weights/offline-readiness.pth")
    assert exported.is_file()
    exported.unlink()
    del checkpoint
    checkpoint = torch.load("assets/pretrained_v2/f0D40k.pth", map_location="cpu")
    assert checkpoint["model"]
    del checkpoint
    assert pathlib.Path("/opt/training-fixture/mute/0_gt_wavs/mute40k.wav").is_file()
    print("rvc: v2/40k training assets and model export verified", flush=True)
    # Exercise the WebUI's real worker and encoder on a synthetic stereo mix.
    with tempfile.TemporaryDirectory(prefix="rvc-separation-") as temporary:
        directory = pathlib.Path(temporary)
        sample_rate = 44100
        time_axis = np.arange(2 * sample_rate, dtype=np.float32) / sample_rate
        left = 0.1 * np.sin(2 * np.pi * 220 * time_axis)
        right = 0.1 * np.sin(2 * np.pi * 330 * time_axis)
        mix = np.stack((left, right), axis=1).astype(np.float32)
        wavfile.write(directory / "synthetic.wav", sample_rate, mix)
        subprocess.run([
            sys.executable, "-c",
            "import sys; from pathlib import Path; p=Path(sys.argv[1]); sys.argv=sys.argv[:1]; "
            "from tools.pymss_webui import pymss_separate, resolve_model, PYMSS_MODEL_CHOICES; "
            "assert PYMSS_MODEL_CHOICES == [resolve_model('vocals-bs-roformer-368').label]; "
            "list(pymss_separate('vocals-bs-roformer-368', str(p/'synthetic.wav'), "
            "str(p/'vocals'), None, str(p/'instrumental'), 'wav'))",
            str(directory),
        ], check=True, timeout=600, env={
            **os.environ, "OMP_NUM_THREADS": "4", "MKL_NUM_THREADS": "4",
        })
        import soundfile as sf
        stems = []
        for name in ("vocals", "instrumental"):
            files = list((directory / name).glob("*.wav"))
            assert len(files) == 1, (name, files)
            data, rate = sf.read(files[0], dtype="float32", always_2d=True)
            assert rate == sample_rate and data.shape == mix.shape
            assert np.isfinite(data).all()
            stems.append(data)
        assert np.allclose(stems[0] + stems[1], mix, atol=1e-4)
    print("rvc: offline stereo vocal/instrumental separation verified", flush=True)

gc.collect()
subprocess.run([sys.executable, "/opt/session.py", "smoke"], check=True)
print(os.environ["APP"] + ": models verified, offline UI ready, IPv4/IPv6 egress blocked")
