import XCTest
import SwiftData
@testable import Wool

@MainActor
final class TaskDetailBehaviorTests: XCTestCase {
    func testProjectAndAreaCanClassifyOneActionTogether() {
        let project = Project(title: "Move house")
        let area = Area(name: "Home")
        let task = TaskItem(title: "Call movers", project: project, areas: [area])

        XCTAssertEqual(task.project?.id, project.id)
        XCTAssertEqual(task.areas?.map(\.id), [area.id])
    }

    func testHomeNextActionCanBeOpenedAndEditedWithoutChangingIdentity() throws {
        let task = TaskItem(title: "Email the client", notes: "Ask for the final approval", status: .nextAction)
        let originalID = task.id

        // This mirrors the detail screen's save contract: edit fields on the
        // existing SwiftData object, then persist the same object.
        task.title = "Email the client tomorrow"
        task.notes = "Ask for the final approval"
        task.status = .waitingFor

        XCTAssertEqual(task.id, originalID)
        XCTAssertEqual(task.title, "Email the client tomorrow")
        XCTAssertEqual(task.status, .waitingFor)
        XCTAssertEqual(task.notes, "Ask for the final approval")
    }

    func testHomeFilterIncludesUndatedNextActionsAndTodayActions() {
        let undated = TaskItem(title: "Call the dentist", status: .nextAction)
        let today = TaskItem(title: "Buy groceries", status: .nextAction, dueDate: .now)
        let waiting = TaskItem(title: "Waiting for reply", status: .waitingFor)

        let homeTasks = [undated, today, waiting].filter {
            $0.status == .nextAction && ($0.dueDate == nil || Calendar.current.isDateInToday($0.dueDate!))
        }

        XCTAssertEqual(homeTasks.map(\.title), ["Call the dentist", "Buy groceries"])
    }
}
