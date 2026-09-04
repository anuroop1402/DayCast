import Foundation

/// What a screen is currently showing.
///
/// One value instead of the usual `isLoading` + `error` + `data` triple, because that
/// triple can express states that do not exist — loading *and* failed, data *and* an error
/// — and every view then has to decide which wins. Here the impossible states are
/// unrepresentable and the view is a `switch` with no default.
///
/// `empty` is deliberately distinct from `loaded([])`. "We searched and found nothing" and
/// "we have results" want different copy, and collapsing them forces the view to re-derive
/// the difference by inspecting the payload.
nonisolated enum ViewState<Value> {
    /// Nothing asked for yet. The resting state of a search screen before the first keystroke.
    case idle
    case loading
    case loaded(Value)
    /// The request succeeded and there is nothing to show. Not an error.
    case empty
    /// Carries the error so the view can ask `isRetryable` rather than offering a retry
    /// button that cannot possibly work.
    case failed(AppError)

    var value: Value? {
        if case .loaded(let value) = self { return value }
        return nil
    }

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    var error: AppError? {
        if case .failed(let error) = self { return error }
        return nil
    }
}

/// `nonisolated` on the enum does **not** carry to its extensions: with
/// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` an unmarked extension is main-actor
/// isolated, which made the `Equatable` conformance below unusable from a `nonisolated`
/// test and failed to compile. Both extensions state it explicitly.
nonisolated extension ViewState where Value: Collection {
    /// Maps a finished request onto `loaded` or `empty` so no call site has to remember
    /// to check `isEmpty` — forgetting it is how "No results" becomes a blank screen.
    init(_ value: Value) {
        self = value.isEmpty ? .empty : .loaded(value)
    }
}

nonisolated extension ViewState: Equatable where Value: Equatable {}
