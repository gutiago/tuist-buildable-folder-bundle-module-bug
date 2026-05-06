import Foundation

public enum BugRepro {
  /// Demonstrates referencing `Bundle.module`.
  /// With Tuist 4.170.0 + `buildableFolders:` and only non-allowlisted resources
  /// (e.g. `.jpg`, `.png`, `.ttf`, `.heic`, `.aar`), `TuistBundle+BugRepro.swift`
  /// is NOT generated, so this fails to compile with:
  ///   error: type 'Bundle' has no member 'module'
  public static func samplePNGURL() -> URL? {
    Bundle.module.url(forResource: "sample", withExtension: "png")
  }
}
