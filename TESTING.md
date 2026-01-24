# Testing

This repository does not include automated tests. Use the image-specific manual checks below.

## Smoke tests (all images)

These are lightweight sanity checks to confirm core tools are present. Run each
command from its corresponding `testing/<image>` directory so the container only
mounts that subtree.

```bash
(cd testing/codex && codexctl run --image codex --temp --cmd bash -lc 'bash --version && git --version && rg --version && jq --version && codex --version')
(cd testing/codex-python && codexctl run --image codex-python --temp --cmd bash -lc 'which python && python -c "import sys; print(sys.executable)"')
(cd testing/codex-office && codexctl run --image codex-office --temp --cmd bash -lc 'python -c "import docx, openpyxl, reportlab; print(\"python-ok\")" && node -e "require(\"pptxgenjs\"); console.log(\"node-ok\")"')
(cd testing/codex-swift && codexctl run --image codex-swift --temp --cmd bash -lc 'swift --version && swift-format --version && command -v format >/dev/null && command -v lint >/dev/null')
```

Optional: run them all at once as a single command (no shell comments):

```bash
(cd testing/codex && codexctl run --image codex --temp --cmd bash -lc 'bash --version && git --version && rg --version && jq --version && codex --version') \
  && (cd testing/codex-python && codexctl run --image codex-python --temp --cmd bash -lc 'which python && python -c "import sys; print(sys.executable)"') \
  && (cd testing/codex-office && codexctl run --image codex-office --temp --cmd bash -lc 'python -c "import docx, openpyxl, reportlab; print(\"python-ok\")" && node -e "require(\"pptxgenjs\"); console.log(\"node-ok\")"') \
  && (cd testing/codex-swift && codexctl run --image codex-swift --temp --cmd bash -lc 'swift --version && swift-format --version && command -v format >/dev/null && command -v lint >/dev/null')
```

## Codex CLI sanity checks (interactive)

These steps confirm Codex itself can connect to the local model, execute shell commands,
and write to the mounted workdir. You need the local model endpoint (Ollama) running.

Base image:

```bash
(cd testing/codex && codexctl run --image codex --temp)
```

In the Codex prompt, paste:

```
Create /workdir/codex-smoke.txt with the text "codex-ok".
Then run: ls -l /workdir/codex-smoke.txt and cat the file.
```

Python image:

```bash
(cd testing/codex-python && codexctl run --image codex-python --temp)
```

Prompt:

```
Create /workdir/codex-python-smoke.txt with the text "python-ok".
Then run: python -c "import sys; print(sys.executable)" and cat the file.
```

Office image:

```bash
(cd testing/codex-office && codexctl run --image codex-office --temp)
```

Prompt:

```
Use python to create /workdir/codex-office-smoke.docx with a single heading "office-ok".
Then run: ls -l /workdir/codex-office-smoke.docx
```

Swift image:

```bash
(cd testing/codex-swift && codexctl run --image codex-swift --temp)
```

Prompt:

```
Create /workdir/Hello.swift with a main that prints "swift-ok".
Then run: swiftc /workdir/Hello.swift -o /workdir/hello && /workdir/hello
```

## Office image (fixtures + verification)

Run the existing office harness inside the `codex-office` image. This verifies the bundled
Python and Node libraries by generating PDF/DOCX/XLSX/PPTX fixtures and then parsing
them to confirm expected text, metadata, and structure.

First, copy the harness into the `testing/codex-office` folder so the container only
mounts that subtree:

```bash
rm -rf testing/codex-office/office_tool_tests
cp -R test-codex-office/office_tool_tests testing/codex-office/
```

```bash
(cd testing/codex-office && codexctl run --image codex-office --temp --cmd bash -lc './office_tool_tests/run.sh')
```

Expected output includes:

- `Fixtures generated in /workdir/test-codex-office/office_tool_tests/fixtures`
- `PPTX verified.`
- `All fixtures verified.`
