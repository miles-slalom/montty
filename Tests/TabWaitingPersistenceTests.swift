// ABOUTME: Verifies a Claude `waiting` state outlasts the redraws that follow its notification
// ABOUTME: and the usual time away from the keyboard, rather than reverting to quieter states.

import Foundation
import Testing
@testable import montty_unit

struct TabWaitingPersistenceTests {
    private let monttyID = "mid-1"

    /// A tab whose one surface entered a hook-driven `.waiting` at `since`.
    private func waitingTab(since: Date) -> (Tab, UUID) {
        let surfaceID = UUID()
        let tab = Tab(surfaceID: surfaceID)
        tab.surfaceToMonttyID[surfaceID] = monttyID
        tab.activityStates[monttyID] = .waiting
        tab.activityWaitingSince[monttyID] = since
        return (tab, surfaceID)
    }

    /// The shell redraws its title as the notification's own command finishes,
    /// and Claude touches it again around then. That is not the user answering.
    @Test func aTitleChangeRightAfterTheNotificationLeavesWaitingAlone() {
        let now = Date()
        let (tab, surfaceID) = waitingTab(since: now.addingTimeInterval(-2))

        let changed = tab.clearWaitingOnTitleChange(for: surfaceID, now: now)

        #expect(changed == false)
        #expect(tab.activityStates[monttyID] == .waiting)
    }

    /// Later title changes are still evidence Claude moved on, in case the hook
    /// that said so was lost.
    @Test func aTitleChangeWellAfterTheNotificationStillClearsWaiting() {
        let now = Date()
        let (tab, surfaceID) = waitingTab(since: now.addingTimeInterval(-30))

        let changed = tab.clearWaitingOnTitleChange(for: surfaceID, now: now)

        #expect(changed == true)
        #expect(tab.activityStates[monttyID] == .working)
    }

    /// A question left unanswered while the user is in a meeting is still a
    /// question, so a few minutes must not turn it into a finished session.
    @Test func waitingSurvivesTheMinutesAUserIsAway() {
        let now = Date()
        let (tab, _) = waitingTab(since: now.addingTimeInterval(-10 * 60))

        let transitioned = tab.sweepStaleWaiting(now: now)

        #expect(transitioned.isEmpty)
        #expect(tab.activityStates[monttyID] == .waiting)
    }

    /// A lost hook must not leave `waiting` up for good.
    @Test func waitingStillGivesUpEventually() {
        let now = Date()
        let (tab, _) = waitingTab(since: now.addingTimeInterval(-45 * 60))

        let transitioned = tab.sweepStaleWaiting(now: now)

        #expect(transitioned == [monttyID])
        #expect(tab.activityStates[monttyID] == .idle)
    }
}
