import SwiftUI
import UIKit

/// Settings' About tab (ADR 0143), the Mac's About panel on the iPad, which has no app menu
/// to hold one: the icon, the name, the version and build, what Treewise is, its links and
/// its licence. The iPad app uses no parts of others, so it has no acknowledgements.
struct AboutSettings: View {
    private static let website = "https://treewise.m-domain.me/"
    private static let source = "https://github.com/mag243/treewise"
    private static let privacy = "https://treewise.m-domain.me/privacy.html"
    private static let licence = "https://github.com/mag243/treewise/blob/main/LICENSE"
    /// The icon's side, in points.
    private static let iconSide: CGFloat = 96
    /// The icon's corner radius, as the Home Screen rounds an icon of that side.
    private static let iconRadius: CGFloat = 22
    /// The room between the header's parts, in points.
    private static let headerSpacing: CGFloat = 8

    var body: some View {
        Form {
            Section {
                header.frame(maxWidth: .infinity)
            }
            .listRowBackground(Color.clear)
            Section {
                link("Website", to: Self.website)
                link("GitHub", to: Self.source)
                link("Privacy", to: Self.privacy)
            } footer: {
                // The licence's name is a link inside the one sentence to translate; the
                // no-break spaces keep it whole when the sentence wraps.
                let name = "Mozilla\u{00A0}Public\u{00A0}License\u{00A0}2.0"
                Text(
                    AttributedString(
                        localized: "Free and open source under the [\(name)](\(Self.licence))."))
            }
        }
        .navigationTitle(Text("About"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(spacing: Self.headerSpacing) {
            if let icon = Self.appIcon {
                Image(uiImage: icon)
                    .resizable()
                    .frame(width: Self.iconSide, height: Self.iconSide)
                    .clipShape(RoundedRectangle(cornerRadius: Self.iconRadius, style: .continuous))
                    .accessibilityHidden(true)
            }
            Text(verbatim: "Treewise").font(.title2.bold())
            Text("Version \(Self.version) (\(Self.build))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            Text("A file manager that works like Windows Explorer, made for the iPad.")
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Self.headerSpacing)
        }
    }

    private func link(_ title: LocalizedStringKey, to address: String) -> some View {
        Link(destination: URL(string: address) ?? URL(fileURLWithPath: "/")) {
            // An image and a text, not a Label: a Label's icon frame lies over its title.
            HStack {
                Image(systemName: "arrow.up.right.square").accessibilityHidden(true)
                Text(title)
            }
        }
    }

    private static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    private static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
    }

    /// The app's own icon, as the asset catalog compiled it into the bundle.
    private static var appIcon: UIImage? {
        let icons = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any]
        let primary = icons?["CFBundlePrimaryIcon"] as? [String: Any]
        let files = primary?["CFBundleIconFiles"] as? [String] ?? []
        let name = files.last ?? primary?["CFBundleIconName"] as? String ?? "AppIcon"
        return UIImage(named: name)
    }
}
