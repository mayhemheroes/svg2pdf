#![no_main]

use libfuzzer_sys::fuzz_target;
use svg2pdf::convert_str;
use svg2pdf::Options;

fuzz_target!(|data: &[u8]| {
    let svg = String::from_utf8_lossy(data);
    let options = Options::default();
    let _ = convert_str(&svg, options);
});