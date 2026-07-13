// Ported from the pre-two-branch integration (archive/original-main:
// fuzz/fuzz_targets/convert_str.rs). Same target name (convert_str) and code
// path: SVG text -> parsed tree -> PDF. The old harness called
// svg2pdf::convert_str(&str, Options), an API removed upstream; the current
// equivalent is usvg::Tree::from_str + svg2pdf::to_pdf, which exercises the
// same parse-and-convert pipeline.
#![no_main]

use libfuzzer_sys::fuzz_target;
use svg2pdf::usvg;
use svg2pdf::{ConversionOptions, PageOptions};

fuzz_target!(|data: &[u8]| {
    let svg = String::from_utf8_lossy(data);
    let options = usvg::Options::default();
    if let Ok(tree) = usvg::Tree::from_str(&svg, &options) {
        let _ = svg2pdf::to_pdf(&tree, ConversionOptions::default(), PageOptions::default());
    }
});
