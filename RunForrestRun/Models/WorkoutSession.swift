import Foundation

/// A completed (or aborted) workout, saved to history.
struct WorkoutSession: Identifiable, Codable, Equatable {
    let id: UUID
    var templateName: String
    var category: WorkoutTemplate.Category
    var startedAt: Date
    var duration: TimeInterval
    var averageHeartRate: Int?
    var peakHeartRate: Int?
    /// Fraction of enforced time spent inside the target band (0...1).
    var timeInZoneFraction: Double
    /// For the zone test: the max HR we observed, if any.
    var measuredMaxHeartRate: Int?
    var samples: [HeartRateSample]

    init(
        id: UUID = UUID(),
        templateName: String,
        category: WorkoutTemplate.Category,
        startedAt: Date,
        duration: TimeInterval,
        averageHeartRate: Int?,
        peakHeartRate: Int?,
        timeInZoneFraction: Double,
        measuredMaxHeartRate: Int?,
        samples: [HeartRateSample]
    ) {
        self.id = id
        self.templateName = templateName
        self.category = category
        self.startedAt = startedAt
        self.duration = duration
        self.averageHeartRate = averageHeartRate
        self.peakHeartRate = peakHeartRate
        self.timeInZoneFraction = timeInZoneFraction
        self.measuredMaxHeartRate = measuredMaxHeartRate
        self.samples = samples
    }
}
