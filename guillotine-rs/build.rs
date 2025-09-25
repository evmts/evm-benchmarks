use std::env;
use std::path::PathBuf;

fn main() {
    // Get the manifest directory (where Cargo.toml is)
    let manifest_dir = env::var("CARGO_MANIFEST_DIR").unwrap();
    let manifest_path = PathBuf::from(&manifest_dir);

    // Compile the stubs C file to provide missing symbols
    cc::Build::new()
        .file("src/stubs.c")
        .compile("stubs");

    // Build the path to the guillotine library
    let guillotine_lib_path = manifest_path
        .parent()
        .unwrap()
        .join("evms")
        .join("guillotine")
        .join("zig-out")
        .join("lib");

    // Tell cargo to look for the library
    println!("cargo:rustc-link-search=native={}", guillotine_lib_path.display());
    // Note: we need to strip both 'lib' prefix and '.a' suffix
    println!("cargo:rustc-link-lib=static=guillotine_ffi_static");

    // Also add the main zig-out/lib directory
    let zig_out_path = manifest_path
        .parent()
        .unwrap()
        .join("zig-out")
        .join("lib");
    println!("cargo:rustc-link-search=native={}", zig_out_path.display());

    // Link system libraries for cryptographic operations
    println!("cargo:rustc-link-lib=c");
    println!("cargo:rustc-link-lib=c++");

    // Tell cargo to invalidate the built crate whenever the wrapper changes
    println!("cargo:rerun-if-changed=wrapper.h");

    // The bindgen::Builder is the main entry point to bindgen
    let bindings = bindgen::Builder::default()
        .header("wrapper.h")
        .parse_callbacks(Box::new(bindgen::CargoCallbacks::new()))
        .generate()
        .expect("Unable to generate bindings");

    // Write the bindings to the $OUT_DIR/bindings.rs file
    let out_path = PathBuf::from(env::var("OUT_DIR").unwrap());
    bindings
        .write_to_file(out_path.join("bindings.rs"))
        .expect("Couldn't write bindings!");
}