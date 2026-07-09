import Foundation
import Combine
import CoreBluetooth

/// Real-time heart rate from any standard Bluetooth LE Heart Rate Service device
/// (0x180D / measurement characteristic 0x2A37). Works with Polar, Garmin, Coros,
/// Wahoo, Scosche and most chest straps / armbands. This is the recommended source
/// for interval alerts because the reading is instantaneous.
final class BLEHeartRateSource: NSObject, HeartRateSource {
    let kind: HeartRateSourceKind = .bluetooth

    private let heartRateServiceUUID = CBUUID(string: "180D")
    private let measurementCharacteristicUUID = CBUUID(string: "2A37")

    private let sampleSubject = PassthroughSubject<HeartRateSample, Never>()
    private let stateSubject = CurrentValueSubject<HeartRateConnectionState, Never>(.disconnected)

    private var central: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var wantsToRun = false

    var samples: AnyPublisher<HeartRateSample, Never> { sampleSubject.eraseToAnyPublisher() }
    var state: AnyPublisher<HeartRateConnectionState, Never> { stateSubject.eraseToAnyPublisher() }

    func start() {
        wantsToRun = true
        if central == nil {
            central = CBCentralManager(delegate: self, queue: nil)
        } else {
            beginScanIfPossible()
        }
    }

    func stop() {
        wantsToRun = false
        central?.stopScan()
        if let peripheral {
            central?.cancelPeripheralConnection(peripheral)
        }
        peripheral = nil
        stateSubject.send(.disconnected)
    }

    private func beginScanIfPossible() {
        guard wantsToRun, let central, central.state == .poweredOn else { return }
        stateSubject.send(.connecting)
        central.scanForPeripherals(withServices: [heartRateServiceUUID], options: nil)
    }
}

extension BLEHeartRateSource: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            beginScanIfPossible()
        case .poweredOff:
            stateSubject.send(.unavailable(reason: "Bluetooth is off"))
        case .unauthorized:
            stateSubject.send(.unavailable(reason: "Bluetooth permission denied"))
        case .unsupported:
            stateSubject.send(.unavailable(reason: "Bluetooth LE not supported"))
        default:
            stateSubject.send(.connecting)
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        central.stopScan()
        self.peripheral = peripheral
        peripheral.delegate = self
        central.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        stateSubject.send(.connected(deviceName: peripheral.name))
        peripheral.discoverServices([heartRateServiceUUID])
    }

    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        stateSubject.send(.disconnected)
        // Auto-reconnect if we still want data.
        if wantsToRun { beginScanIfPossible() }
    }

    func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        stateSubject.send(.disconnected)
        if wantsToRun { beginScanIfPossible() }
    }
}

extension BLEHeartRateSource: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let service = peripheral.services?.first(where: { $0.uuid == heartRateServiceUUID }) else { return }
        peripheral.discoverCharacteristics([measurementCharacteristicUUID], for: service)
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        guard let characteristic = service.characteristics?
            .first(where: { $0.uuid == measurementCharacteristicUUID }) else { return }
        peripheral.setNotifyValue(true, for: characteristic)
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard characteristic.uuid == measurementCharacteristicUUID,
              let data = characteristic.value,
              let bpm = Self.parseHeartRate(from: data) else { return }
        sampleSubject.send(HeartRateSample(bpm: bpm, timestamp: Date(), origin: .ble))
    }

    /// Parse the Bluetooth Heart Rate Measurement characteristic (0x2A37).
    /// Bit 0 of the flags byte selects 8-bit vs 16-bit HR value.
    static func parseHeartRate(from data: Data) -> Int? {
        guard let flags = data.first else { return nil }
        let is16Bit = (flags & 0x01) != 0
        if is16Bit {
            guard data.count >= 3 else { return nil }
            return Int(data[1]) | (Int(data[2]) << 8)
        } else {
            guard data.count >= 2 else { return nil }
            return Int(data[1])
        }
    }
}
