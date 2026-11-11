
import SwiftUI
import HealthKit
import WatchKit
import AVFoundation
import UserNotifications
import Combine

// MARK: - Alarm Sound

final class AlarmSoundManager {

    static let shared = AlarmSoundManager()

    private var player: AVAudioPlayer?

    func start() {

        guard let url = Bundle.main.url(
            forResource: "alarm",
            withExtension: "wav"
        ) else {
            print("ERROR: alarm.wav not found")
            return
        }

        do {
            let audioSession = AVAudioSession.sharedInstance()

            try audioSession.setCategory(
                .playback,
                mode: .default
            )

            try audioSession.setActive(true)

            player?.stop()

            player = try AVAudioPlayer(contentsOf: url)
            player?.numberOfLoops = -1
            player?.volume = 1.0
            player?.prepareToPlay()

            _ = player?.play()

        } catch {
            print("Alarm sound error: \(error)")
        }
    }

    func stop() {
        player?.stop()
        player = nil
    }
}

// MARK: - Health Manager

final class HealthManager: ObservableObject {

    @Published var heartRate: Double?
    @Published var steps: Int?
    @Published var hrv: Double?

    @Published var status = "Loading health data..."
    @Published var alertMessage: String?

    @Published var alarmActive = false
    @Published var isTestAlert = false
    @Published var showEmergencyConfirmation = false

    let emergencyNumber = "998"

    private let healthStore = HKHealthStore()

    private var heartRateQuery: HKAnchoredObjectQuery?
    private var hapticTimer: Timer?

    private var hasStarted = false
    private var lastAlertType: String?

    // Example thresholds only, not medical limits.
    private let highLimit = 120.0
    private let lowLimit = 50.0

    // Correct HealthKit quantity types

    private var heartType: HKQuantityType {
        HKObjectType.quantityType(
            forIdentifier: .heartRate
        )!
    }

    private var stepsType: HKQuantityType {
        HKObjectType.quantityType(
            forIdentifier: .stepCount
        )!
    }

    private var hrvType: HKQuantityType {
        HKObjectType.quantityType(
            forIdentifier: .heartRateVariabilitySDNN
        )!
    }

    // MARK: - Automatic Setup

    func start() {

        guard !hasStarted else {
            refresh()
            return
        }

        hasStarted = true

        guard HKHealthStore.isHealthDataAvailable() else {
            status = "HealthKit unavailable"
            return
        }

        UNUserNotificationCenter.current()
            .requestAuthorization(
                options: [.alert, .sound]
            ) { _, _ in }

        let readTypes: Set<HKObjectType> = [
            heartType,
            stepsType,
            hrvType
        ]

        healthStore.requestAuthorization(
            toShare: [],
            read: readTypes
        ) { [weak self] _, error in

            DispatchQueue.main.async {

                guard let self = self else {
                    return
                }

                if let error = error {
                    self.status = error.localizedDescription
                    return
                }

                self.status = "Health data ready"

                self.refresh()
                self.observeHeartRate()
            }
        }
    }

    // MARK: - Refresh Health Data

    func refresh() {
        readLatestHeartRate()
        readSteps()
        readHRV()
    }

    // MARK: - Latest Heart Rate

    private func readLatestHeartRate() {

        let query = HKSampleQuery(
            sampleType: heartType,
            predicate: nil,
            limit: 1,
            sortDescriptors: [
                NSSortDescriptor(
                    key: HKSampleSortIdentifierEndDate,
                    ascending: false
                )
            ]
        ) { [weak self] _, samples, _ in

            guard let sample =
                samples?.first as? HKQuantitySample
            else {
                return
            }

            self?.handleHeartRate(sample)
        }

        healthStore.execute(query)
    }

    // MARK: - Observe New Heart Rate Samples

    private func observeHeartRate() {

        guard heartRateQuery == nil else {
            return
        }

        let query = HKAnchoredObjectQuery(
            type: heartType,
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, _ in

            self?.handleNewestSample(samples)
        }

        query.updateHandler = {
            [weak self] _, samples, _, _, _ in

            self?.handleNewestSample(samples)
        }

        heartRateQuery = query

        healthStore.execute(query)
    }

    private func handleNewestSample(
        _ samples: [HKSample]?
    ) {

        let latest = samples?
            .compactMap {
                $0 as? HKQuantitySample
            }
            .max {
                $0.endDate < $1.endDate
            }

        guard let latest = latest else {
            return
        }

        handleHeartRate(latest)
    }

    private func handleHeartRate(
        _ sample: HKQuantitySample
    ) {

        let unit = HKUnit.count().unitDivided(
            by: HKUnit.minute()
        )

        let bpm = sample.quantity.doubleValue(
            for: unit
        )

        DispatchQueue.main.async {

            self.heartRate = bpm

            self.checkAlert(
                bpm,
                sampleDate: sample.endDate
            )
        }
    }

    // MARK: - Steps

    private func readSteps() {

        let startDate = Calendar.current.startOfDay(
            for: Date()
        )

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: Date(),
            options: .strictStartDate
        )

        let query = HKStatisticsQuery(
            quantityType: stepsType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { [weak self] _, statistics, _ in

            let count = statistics?
                .sumQuantity()?
                .doubleValue(
                    for: HKUnit.count()
                )

            DispatchQueue.main.async {

                self?.steps = count.map {
                    Int($0)
                }
            }
        }

        healthStore.execute(query)
    }

    // MARK: - HRV

    private func readHRV() {

        let query = HKSampleQuery(
            sampleType: hrvType,
            predicate: nil,
            limit: 1,
            sortDescriptors: [
                NSSortDescriptor(
                    key: HKSampleSortIdentifierEndDate,
                    ascending: false
                )
            ]
        ) { [weak self] _, samples, _ in

            let sample =
                samples?.first as? HKQuantitySample

            let milliseconds = HKUnit.secondUnit(
                with: .milli
            )

            let value = sample?.quantity.doubleValue(
                for: milliseconds
            )

            DispatchQueue.main.async {
                self?.hrv = value
            }
        }

        healthStore.execute(query)
    }

    // MARK: - Automatic Heart Rate Alerts

    private func checkAlert(
        _ bpm: Double,
        sampleDate: Date
    ) {

        let age = Date().timeIntervalSince(
            sampleDate
        )

        // Never alert from an old reading.
        guard age >= 0 && age <= 300 else {
            return
        }

        // Keep test mode separate.
        if isTestAlert {
            return
        }

        var alertType: String?
        var message: String?

        if bpm > highLimit {

            alertType = "high"
            message = "High heart rate: \(Int(bpm)) BPM"

        } else if bpm < lowLimit {

            alertType = "low"
            message = "Low heart rate: \(Int(bpm)) BPM"
        }

        if let alertType = alertType,
           let message = message {

            alertMessage = message

            if lastAlertType != alertType {

                lastAlertType = alertType

                startAlarm()
                sendNotification(message)
            }

        } else {

            lastAlertType = nil
            alertMessage = nil

            stopAlarm()
        }
    }

    // MARK: - Test Alert

    func testAlert() {

        stopAlarm()

        isTestAlert = true
        alertMessage = "TEST: Sound + vibration"

        startAlarm()
    }

    // MARK: - Sound + Haptics

    private func startAlarm() {

        guard !alarmActive else {
            return
        }

        alarmActive = true

        AlarmSoundManager.shared.start()

        WKInterfaceDevice.current()
            .play(.notification)

        hapticTimer?.invalidate()

        hapticTimer = Timer.scheduledTimer(
            withTimeInterval: 2.0,
            repeats: true
        ) { [weak self] _ in

            guard self?.alarmActive == true else {
                return
            }

            WKInterfaceDevice.current()
                .play(.notification)
        }
    }

    func stopAlarm() {

        alarmActive = false

        hapticTimer?.invalidate()
        hapticTimer = nil

        AlarmSoundManager.shared.stop()

        if isTestAlert {

            isTestAlert = false
            alertMessage = nil
        }
    }

    // MARK: - Local Notifications

    private func sendNotification(
        _ message: String
    ) {

        let content = UNMutableNotificationContent()

        content.title = "Early Warning"
        content.body = message
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current()
            .add(request)
    }

    // MARK: - Emergency Number 998

    func callEmergency() {

        guard !isTestAlert else {
            return
        }

        guard let url = URL(
            string: "tel:\(emergencyNumber)"
        ) else {
            return
        }

        WKApplication.shared().openSystemURL(url)
    }
}

// MARK: - Main Watch Screen

struct ContentView: View {

    @StateObject private var health = HealthManager()

    private let refreshTimer = Timer.publish(
        every: 60,
        on: .main,
        in: .common
    ).autoconnect()

    var body: some View {

        ScrollView {

            VStack(spacing: 12) {

                Image(systemName: "heart.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.red)

                Text("Early Warning")
                    .font(.headline)

                Text(health.status)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    health.refresh()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .tint(.purple)

                Divider()

                // Heart Rate

                Text("HEART RATE")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(
                    health.heartRate.map {
                        "\(Int($0))"
                    } ?? "--"
                )
                .font(
                    .system(
                        size: 44,
                        weight: .bold
                    )
                )
                .foregroundStyle(.red)

                Text("BPM")
                    .font(.caption2)

                Divider()

                // Steps

                HStack {

                    Label(
                        "Steps",
                        systemImage: "figure.walk"
                    )

                    Spacer()

                    Text(
                        health.steps.map {
                            "\($0)"
                        } ?? "--"
                    )
                }
                .font(.caption)

                // HRV

                HStack {

                    Label(
                        "HRV",
                        systemImage: "waveform.path.ecg"
                    )

                    Spacer()

                    Text(
                        health.hrv.map {
                            String(
                                format: "%.1f ms",
                                $0
                            )
                        } ?? "--"
                    )
                }
                .font(.caption)

                Divider()

                // Alert Area

                if let message = health.alertMessage {

                    Image(
                        systemName:
                            "exclamationmark.triangle.fill"
                    )
                    .font(.title2)
                    .foregroundStyle(.orange)

                    Text(
                        health.isTestAlert
                            ? "TEST ALERT"
                            : "HEALTH WARNING"
                    )
                    .font(.headline)
                    .foregroundStyle(.orange)

                    Text(message)
                        .font(.caption)
                        .multilineTextAlignment(.center)

                    if health.alarmActive {

                        Button("Stop Alarm 🛑") {
                            health.stopAlarm()
                        }
                        .tint(.red)
                    }

                } else {

                    Label(
                        "No active alerts",
                        systemImage:
                            "checkmark.shield.fill"
                    )
                    .font(.caption2)
                    .foregroundStyle(.green)
                }

                // Emergency button always visible.

                Button("Emergency 998 🚑") {

                    health.showEmergencyConfirmation = true
                }
                .tint(.red)

                // Manual test button.

                Button("Test Alert 🚨") {

                    health.testAlert()
                }
                .tint(.orange)
            }
            .padding()
        }

        .onAppear {

            health.start()
        }

        .onReceive(refreshTimer) { _ in

            health.refresh()
        }

        .alert(
            health.isTestAlert
                ? "Emergency Button Test"
                : "Emergency Call",
            isPresented:
                $health.showEmergencyConfirmation
        ) {

            Button(
                "Cancel",
                role: .cancel
            ) { }

            if !health.isTestAlert {

                Button(
                    "Continue to Call",
                    role: .destructive
                ) {

                    health.callEmergency()
                }
            }

        } message: {

            if health.isTestAlert {

                Text(
                    "This is a test. No emergency call will be made."
                )

            } else {

                Text(
                    "Open the emergency call option for 998?"
                )
            }
        }
    }
}

#Preview {
    ContentView()
}
