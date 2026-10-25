import hashlib
import pathlib
import sys
import zipfile

app = sys.argv[1]
root = pathlib.Path("/opt/app")
if app == "facefusion":
    sys.path.insert(0, str(root))
    from facefusion import state_manager
    from facefusion.args import apply_args
    from facefusion.program import create_program
    from facefusion.core import common_pre_check, processors_pre_check

    args = vars(create_program().parse_args([
        "run", "--execution-providers", "cpu",
        "--processors", "face_swapper",
    ]))
    apply_args(args, state_manager.init_item)
    if not common_pre_check() or not processors_pre_check():
        raise RuntimeError("FaceFusion model preparation failed")
else:
    for relative in (
        "hubert_base/config.json",
        "hubert_base/preprocessor_config.json",
        "hubert_base/pytorch_model.bin",
        "rmvpe.pt",
    ):
        destination = root / "assets" / relative
        if relative == "rmvpe.pt":
            destination = root / "assets/rmvpe/rmvpe.pt"
        destination.parent.mkdir(parents=True, exist_ok=True)
        if not destination.is_file():
            raise FileNotFoundError("Missing checksum-pinned public model: " + str(destination))
    for directory in ("weights", "indices", "pretrained", "pretrained_v2", "pymss_weights"):
        (root / "assets" / directory).mkdir(parents=True, exist_ok=True)
    # Mutable working data stays outside the immutable application tree.
    for name, destination in (
        ("TEMP", "/tmp/rvc-temp"),
        ("assets/weights", "/work/state/weights"),
        ("logs", "/work/state"),
    ):
        path = root / name
        if path.exists():
            import shutil
            shutil.rmtree(path)
        path.symlink_to(destination)

    # Expose only separation models that are actually baked into this image.
    separation = root / "tools/pymss_webui.py"
    original = "PYMSS_MODEL_CHOICES = [spec.label for spec in MODEL_SPECS]"
    replacement = """PYMSS_MODEL_CHOICES = [
    spec.label for spec in MODEL_SPECS
    if (weight_pymss_root / spec.model_file).is_file()
    and (weight_pymss_root / spec.config_file).is_file()
]"""
    code = separation.read_text()
    if code.count(original) != 1:
        raise RuntimeError("Pinned RVC separation model selector has changed")
    separation.write_text(code.replace(original, replacement))
    webui = root / "webui.py"
    code = webui.read_text()
    for label, destination in (
        ("主结果文件夹", "/work/output/vocals"),
        ("分离残余文件夹", "/work/output/instrumental"),
    ):
        original = 'label=i18n("' + label + '"), value="opt"'
        if code.count(original) != 1:
            raise RuntimeError("Pinned RVC separation output selector has changed")
        code = code.replace(original, 'label=i18n("' + label + '"), value="' + destination + '"')
    webui.write_text(code)

    # Bake only the public silence fixture; personal datasets never enter the build.
    with zipfile.ZipFile(root / "assets/mute.zip") as archive:
        destination = pathlib.Path("/opt/training-fixture")
        for entry in archive.infolist():
            target = (destination / entry.filename).resolve()
            if not target.is_relative_to(destination):
                raise ValueError("Invalid public silence archive member")
        archive.extractall(destination)

with open("/opt/model-checksums.sha256", "w") as manifest:
    for directory in (root / ".assets", root / "assets"):
        if directory.exists():
            for path in sorted(directory.rglob("*")):
                if path.is_file():
                    digest = hashlib.file_digest(path.open("rb"), "sha256").hexdigest()
                    manifest.write(digest + "  " + str(path) + "\n")
