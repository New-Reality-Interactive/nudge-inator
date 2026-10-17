/// What a tab's content area shows, from the model's launch state.
enum ScreenState: Equatable {
    /// The store is still being read. Showing the empty state now would say "All clear" before
    /// anything is known.
    case loading
    /// The tab's own content. Also without a model (the app hosting tests, and previews).
    case ready
    /// The store couldn't be read (ticket 21). The tabs say so and that nudges already pending
    /// still come.
    case storeUnreadable

    @MainActor
    init(model: AppModel?) {
        switch model?.launchState {
        case nil, .ready: self = .ready
        case .launching: self = .loading
        case .storeUnreadable: self = .storeUnreadable
        }
    }
}
