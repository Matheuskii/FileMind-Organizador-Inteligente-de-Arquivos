from examples.demo import create_samples, run_demo
from main import digest, extract, fingerprint


def test_generated_pdf_has_extractable_text(tmp_path):
    sources = create_samples(tmp_path)
    pdf = next(path for path in sources if path.suffix == ".PDF")
    assert "Apostila de Python" in extract(pdf, 12000, 8, False, "por")["text"]


def test_offline_demo_preserves_all_originals_and_repeated_runs(tmp_path, monkeypatch):
    def forbid_api(*args, **kwargs):
        raise AssertionError("Demonstração offline não deve instanciar Groq")

    monkeypatch.setattr("main.Groq", forbid_api)
    monkeypatch.setattr("main.wait_ready", lambda path, *_: fingerprint(path))
    first, targets = run_demo(tmp_path)
    assert len(targets) == 4
    for source in (first / "entrada").iterdir():
        assert any(target.suffix == source.suffix and digest(target) == digest(source) for target in targets)
    second, other_targets = run_demo(tmp_path)
    assert first != second
    assert len(other_targets) == 4
    assert all(target.exists() for target in targets)
