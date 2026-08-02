import Foundation
import WebKit

enum HTMLRuntimeSecurityMode: Equatable {
    case isolated
    case trusted
}

enum HTMLRuntimeSecurityPolicy {
    static let ruleListIdentifier = "Chiselo.IsolatedHTML.v1"

    static let remoteResourceBlockingRules = """
    [
      {
        "trigger": {
          "url-filter": "^https?://",
          "resource-type": ["document", "image", "style-sheet", "script", "font", "media", "svg-document", "raw"]
        },
        "action": { "type": "block" }
      }
    ]
    """

    static func allowsNavigation(
        to url: URL?,
        isMainFrame: Bool,
        mode: HTMLRuntimeSecurityMode,
        editorURL: URL?
    ) -> Bool {
        guard let url else { return true }

        if isMainFrame {
            guard url.isFileURL, let editorURL else { return false }
            return url.standardizedFileURL == editorURL.standardizedFileURL
        }

        guard mode == .isolated else { return true }
        switch url.scheme?.lowercased() {
        case "http", "https", "ws", "wss":
            return false
        default:
            return true
        }
    }
}

@MainActor
final class HTMLRuntimeSecurityController {
    private var installedRuleList: WKContentRuleList?
    private var requestGeneration = 0

    func apply(
        _ mode: HTMLRuntimeSecurityMode,
        to userContentController: WKUserContentController,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        requestGeneration += 1
        let generation = requestGeneration

        if let installedRuleList {
            userContentController.remove(installedRuleList)
            self.installedRuleList = nil
        }

        guard mode == .isolated else {
            completion(.success(()))
            return
        }

        WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: HTMLRuntimeSecurityPolicy.ruleListIdentifier,
            encodedContentRuleList: HTMLRuntimeSecurityPolicy.remoteResourceBlockingRules
        ) { [weak self, weak userContentController] ruleList, error in
            DispatchQueue.main.async {
                guard let self, generation == self.requestGeneration else { return }
                if let error {
                    completion(.failure(error))
                    return
                }
                guard let ruleList, let userContentController else {
                    completion(.failure(HTMLRuntimeSecurityError.ruleListUnavailable))
                    return
                }
                userContentController.add(ruleList)
                self.installedRuleList = ruleList
                completion(.success(()))
            }
        }
    }
}

enum HTMLRuntimeSecurityError: LocalizedError {
    case ruleListUnavailable

    var errorDescription: String? {
        switch self {
        case .ruleListUnavailable:
            return "无法安装静态安全模式的网络隔离规则。"
        }
    }
}
