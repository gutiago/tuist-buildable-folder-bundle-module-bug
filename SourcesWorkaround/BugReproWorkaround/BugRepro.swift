import Foundation

public enum BugReproWorkaround {
  /// Same code as `BugRepro`, but the target uses explicit `sources:` + `resources:`
  /// instead of `buildableFolders:`. With explicit `resources:`, Tuist treats the
  /// target's `target.resources.resources` as non-empty and synthesises
  /// `TuistBundle+BugReproWorkaround.swift`, so `Bundle.module` resolves.
  public static func samplePNGURL() -> URL? {
    Bundle.module.url(forResource: "sample", withExtension: "png")
  }
}
