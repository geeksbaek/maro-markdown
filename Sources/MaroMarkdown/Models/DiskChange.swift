import Foundation

/// What to do when the watched file changed on disk.
enum DiskChange: Equatable {
    /// The window already shows what is on disk.
    case upToDate
    /// The file holds an earlier save from this window, not another app's change.
    case ownSave
    /// Another app changed the file and the window has unsaved edits.
    case conflict
    /// Another app changed the file and it can be read again.
    case reload

    static func decide(
        diskText: String,
        windowText: String,
        diskDate: Date?,
        lastSaveDate: Date?,
        hasUnsavedEdits: Bool,
        discardingEdits: Bool = false
    ) -> DiskChange {
        if diskText == windowText { return .upToDate }
        if discardingEdits { return .reload }
        // Saving updates the document's modification date, so a matching
        // date means this window wrote the file and has been edited since.
        if let diskDate, diskDate == lastSaveDate { return .ownSave }
        return hasUnsavedEdits ? .conflict : .reload
    }
}
