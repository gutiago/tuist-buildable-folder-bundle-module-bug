import SwiftUI

public struct MyLibView: View {
  public init() {}

  public var body: some View {
    // `actionDeleted` is the actool-generated identifier for
    // `action-deleted.imageset` (kebab-case → camelCase).
    Image(.actionDeleted)
  }
}
