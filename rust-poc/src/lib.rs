//! Phase 0 proof of concept slice of Square's audio stack.
//!
//! Square measures the loudness of local files with the `ebur128`
//! crate (MIT) so they play at the level of streamed tracks. This crate
//! exposes that single, legally distributable capability behind a
//! small C ABI, to prove the Rust to iOS toolchain path end to end:
//! compile for `aarch64-apple-ios` and `aarch64-apple-ios-sim`, then
//! package the static libraries as an XCFramework.
//!
//! Nothing here talks to Spotify or YouTube, and nothing from the
//! Android project's GPL code is copied into this crate. The crate
//! itself is released under GPL-3.0-or-later to stay consistent with
//! the project it belongs to.

use std::os::raw::c_char;

/// Version string for the proof of concept crate, as a C string.
///
/// # Safety
/// The returned pointer is a static C string and must not be freed.
#[no_mangle]
pub extern "C" fn square_core_poc_version() -> *const c_char {
    c"square-core-poc 0.1.0".as_ptr()
}

/// Integrated loudness (LUFS) of an interleaved i16 PCM buffer.
///
/// Returns NaN for an empty buffer or invalid parameters.
///
/// # Safety
/// `samples` must point to `frame_count * channels` readable i16
/// values, or be null when `frame_count` is 0.
#[no_mangle]
pub extern "C" fn square_core_poc_loudness_i16(
    samples: *const i16,
    frame_count: usize,
    channels: u32,
    sample_rate: u32,
) -> f64 {
    if samples.is_null() || frame_count == 0 || channels == 0 || sample_rate == 0 {
        return f64::NAN;
    }
    let total = match frame_count.checked_mul(channels as usize) {
        Some(total) => total,
        None => return f64::NAN,
    };
    let slice = unsafe { std::slice::from_raw_parts(samples, total) };
    let mut meter = match ebur128::EbuR128::new(channels, sample_rate, ebur128::Mode::I) {
        Ok(meter) => meter,
        Err(_) => return f64::NAN,
    };
    if meter.add_frames_i16(slice).is_err() {
        return f64::NAN;
    }
    meter.loudness_global().unwrap_or(f64::NAN)
}

/// Peak level of an f32 buffer as a plain Rust function, exercised by
/// the crate's tests and kept for the Swift side to call later.
pub fn peak(samples: &[f32]) -> f32 {
    samples.iter().fold(0.0f32, |acc, s| acc.max(s.abs()))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn peak_of_silence_is_zero() {
        assert_eq!(peak(&[0.0, 0.0, -0.0]), 0.0);
    }

    #[test]
    fn loudness_of_silence_is_nan_or_negative_infinity_free() {
        let samples = vec![0i16; 48_000 * 2];
        let value = square_core_poc_loudness_i16(samples.as_ptr(), 48_000, 2, 48_000);
        // Silence has no finite integrated loudness; the call must not
        // panic and must not invent a level.
        assert!(value.is_nan() || value == f64::NEG_INFINITY || value < -60.0);
    }
}
