#!/usr/bin/env bash
#
# mayhem/test.sh — RUN svg2pdf's OWN upstream test suite (already compiled by
# mayhem/build.sh via `cargo test --no-run` into $SRC/mayhem-tests-target) and
# emit a CTRF summary.
#
# PATCH-grade oracle: the svg2pdf-tests crate holds ~1800 generated visual
# regression tests (tests/src/render.rs, from the resvg suite + custom cases):
# each converts an SVG to PDF, renders the PDF through pdfium (chromium/5880,
# the exact build upstream CI pins) and pixel-compares against a committed
# reference PNG, plus API known-answer tests (tests/src/api.rs). A no-op /
# exit(0) patch to the converter fails the pixel comparisons. Neutered test
# binaries emitting no `test result:` lines are also detected structurally.
set -uo pipefail
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH
cd "$SRC"

# emit_ctrf <tool> <passed> <failed> [skipped] [pending] [other]
emit_ctrf() {
  local tool="$1" passed="$2" failed="$3" skipped="${4:-0}" pending="${5:-0}" other="${6:-0}"
  local tests=$(( passed + failed + skipped + pending + other ))
  cat > "${CTRF_REPORT:-$SRC/ctrf-report.json}" <<JSON
{
  "results": {
    "tool": { "name": "$tool" },
    "summary": {
      "tests": $tests,
      "passed": $passed,
      "failed": $failed,
      "pending": $pending,
      "skipped": $skipped,
      "other": $other
    }
  }
}
JSON
  printf 'CTRF {"results":{"tool":{"name":"%s"},"summary":{"tests":%d,"passed":%d,"failed":%d,"pending":%d,"skipped":%d,"other":%d}}}\n' \
    "$tool" "$tests" "$passed" "$failed" "$pending" "$skipped" "$other"
  [ "$failed" -eq 0 ]
}

# RUN the pre-built test binaries directly (no cargo, no recompilation — build.sh compiled
# them). `cargo test --no-run` left one executable per test target under
# mayhem-tests-target/release/deps: svg2pdf-* (lib), svg2pdf_tests-* (the render/api
# suite), svg2pdf_cli-*. The tests crate loads ./pdfium, ./svg, ./fonts relative to
# tests/, so run everything from there (harmless for the other binaries).
TDIR="$SRC/mayhem-tests-target/release/deps"
[ -d "$TDIR" ] || { echo "ERROR: $TDIR missing — build.sh should have built the test suite" >&2; emit_ctrf cargo-test 0 1; exit 1; }
[ -f "$SRC/tests/pdfium/libpdfium.so" ] || { echo "ERROR: tests/pdfium/libpdfium.so missing — build.sh should have installed it" >&2; emit_ctrf cargo-test 0 1; exit 1; }

OUT="$(mktemp)"
for bin in "$TDIR"/svg2pdf-* "$TDIR"/svg2pdf_tests-* "$TDIR"/svg2pdf_cli-*; do
  [ -f "$bin" ] && [ -x "$bin" ] || continue
  case "$bin" in *.d|*.so|*.rlib) continue ;; esac
  echo "=== running $(basename "$bin") ==="
  ( cd "$SRC/tests" && "$bin" ) 2>&1 | tee -a "$OUT"
done

# Sum every `test result: ok. X passed; Y failed; ... Z ignored` line.
sum_field() { grep -E '^test result:' "$OUT" | sed -E "s/.* ([0-9]+) $1.*/\1/" | awk '{s+=$1} END {print s+0}'; }
PASSED=$(sum_field passed)
FAILED=$(sum_field failed)
SKIPPED=$(sum_field ignored)
: "${PASSED:=0}" "${FAILED:=0}" "${SKIPPED:=0}"
rm -f "$OUT"

# No parsed results at all (e.g. neutered binaries emitting nothing) → honest failure.
if [ "$(( PASSED + FAILED + SKIPPED ))" -eq 0 ]; then
  echo "ERROR: no 'test result:' lines parsed — test binaries produced no results" >&2
  emit_ctrf cargo-test 0 1; exit 1
fi

emit_ctrf cargo-test "$PASSED" "$FAILED" "$SKIPPED"
