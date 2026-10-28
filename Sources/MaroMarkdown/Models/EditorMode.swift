import Foundation

enum EditorMode: String, CaseIterable, Identifiable {
    case source
    case split
    case preview

    var id: String { rawValue }

    var title: String {
        switch self {
        case .source: "편집"
        case .split: "나란히"
        case .preview: "미리보기"
        }
    }

    var systemImage: String {
        switch self {
        case .source: "square.and.pencil"
        case .split: "rectangle.split.2x1"
        case .preview: "eye"
        }
    }
}
