import SwiftUI
import CoreLocation

final class Rangefinder: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var location: CLLocation?
    @Published private(set) var busy = false
    @Published private(set) var message: String?
    private let manager = CLLocationManager()
    private var timeout: DispatchWorkItem?
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }
    func request() {
        guard !busy else { return }
        busy = true; message = nil; location = nil
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse: measure()
        default: busy = false; message = "設定で位置情報の利用を許可してください。"
        }
    }
    private func measure() {
        timeout?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.cancel(); self?.message = "測位できませんでした。空の開けた場所で再試行してください。"
        }
        timeout = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 20, execute: work)
        manager.requestLocation()
    }
    func cancel() {
        timeout?.cancel(); timeout = nil
        manager.stopUpdatingLocation(); busy = false
    }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard busy else { return }
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse: measure()
        case .denied, .restricted: cancel(); message = "位置情報が許可されていません。スコア入力は利用できます。"
        default: break
        }
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard busy else { return }
        cancel()
        guard let fix = locations.last, fix.horizontalAccuracy >= 0,
              fix.horizontalAccuracy <= 50, abs(fix.timestamp.timeIntervalSinceNow) <= 15 else {
            message = "GPSの精度が不足しています。距離を更新し直してください。"; return
        }
        location = fix
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard busy else { return }
        cancel(); message = "測位できませんでした。位置情報設定と受信環境を確認してください。"
    }
    func yards(to target: Coordinate) -> Int? {
        guard let location else { return nil }
        let here = Coordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        let distance = here.meters(to: target)
        guard distance <= 2_000 else { return nil }
        return Int((distance / 0.9144).rounded())
    }
}
