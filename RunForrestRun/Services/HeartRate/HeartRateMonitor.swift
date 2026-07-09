import Foundation
import Combine

/// The single object the UI and workout engine observe for heart rate. It wraps
/// whichever `HeartRateSource` is currently selected and republishes its data.
@MainActor
final class HeartRateMonitor: ObservableObject {
    @Published private(set) var currentHeartRate: Int?
    @Published private(set) var connectionState: HeartRateConnectionState = .disconnected
    @Published private(set) var lastSample: HeartRateSample?
    @Published var sourceKind: HeartRateSourceKind {
        didSet {
            guard sourceKind != oldValue else { return }
            switchSource(to: sourceKind)
        }
    }

    private var source: HeartRateSource?
    private var cancellables = Set<AnyCancellable>()
    private let sourceFactory: (HeartRateSourceKind) -> HeartRateSource

    init(
        initialKind: HeartRateSourceKind = .bluetooth,
        sourceFactory: @escaping (HeartRateSourceKind) -> HeartRateSource
    ) {
        self.sourceKind = initialKind
        self.sourceFactory = sourceFactory
        switchSource(to: initialKind)
    }

    var isStreaming: Bool { connectionState.isLive }

    func start() { source?.start() }
    func stop() { source?.stop() }

    /// Rebuild the current source from the factory — used after credentials change
    /// (e.g. saving the Oura ring key) so the new source picks them up.
    func reloadSource() { switchSource(to: sourceKind) }

    private func switchSource(to kind: HeartRateSourceKind) {
        source?.stop()
        cancellables.removeAll()
        currentHeartRate = nil
        connectionState = .disconnected

        let newSource = sourceFactory(kind)
        source = newSource

        newSource.samples
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sample in
                self?.currentHeartRate = sample.bpm
                self?.lastSample = sample
            }
            .store(in: &cancellables)

        newSource.state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.connectionState = state
            }
            .store(in: &cancellables)

        newSource.start()
    }
}
