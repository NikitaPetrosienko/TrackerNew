
import UIKit

struct Tracker {
    let id: UUID
    let title: String
    let color: UIColor
    let emoji: String
    let schedule: Set<WeekDay>
    let isPinned: Bool
    let creationDate: Date?
}

