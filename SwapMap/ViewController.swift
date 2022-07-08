import UIKit
import MapKit
import CoreLocation

final class ViewController: UIViewController {

    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var adressLabel: UILabel!
    
    private let locationManager = CLLocationManager()
    private let regionInMeters: Double = 10000
    private var previousLocation: CLLocation?
    private var directionsArray: [MKDirections] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        checkLocationServices()
        makeButton()
    }
    
//    MARK: - Helper functions
    
    private func makeButton() {
        let goButton = UIButton(type: .system)
        goButton.frame = CGRect(x: 295, y: 650, width: 60, height: 60)
        goButton.backgroundColor = .systemBlue
        
        goButton.setTitle("GO", for: .normal)
        goButton.titleLabel?.font = UIFont(name: "DIN Alternate Bold",
                                           size: 25)
        goButton.setTitleColor(.white, for: .normal)
        
        goButton.layer.cornerRadius = 30
        goButton.layer.masksToBounds = false
        goButton.layer.shadowColor = UIColor.gray.cgColor
        goButton.layer.shadowOffset = CGSize(width: 2, height: 5)
        goButton.layer.shadowOpacity = 0.7
        goButton.layer.shadowRadius = 2
        
        goButton.addTarget(self, action: #selector(goButtonTapped(_:)), for: .touchUpInside)
        
        view.addSubview(goButton)
    }
    
    @objc private func goButtonTapped(_ sender: UIButton) {
        getDirections()
    }
    
    private func makeAlert(title: String, message: String) {
        let alert = UIAlertController(title: title,
                                      message: message,
                                      preferredStyle: .alert)
        let action = UIAlertAction(title: "OK", style: .default)
        alert.addAction(action)
        self.present(alert, animated: true, completion: nil)
    }
    
//    MARK: - Set Current Location
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    private func checkLocationServices() {
        if CLLocationManager.locationServicesEnabled() {
            setupLocationManager()
            checkLocationAuthorization()
        } else {
            makeAlert(title: "Turn On Location Services to Allow \"SwapMap\" to Determine Your Location",
                      message: "Go to Settings > Privacy > Location Services")
        }
    }
    
    private func checkLocationAuthorization() {
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse:
           startTrackingUserLocation()
        case .denied:
            makeAlert(title: "Allow \"SwapMap\" to Access Your Location",
                      message: "Go to Settings > Screen Time > Content & Privacy Restrictions")
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .restricted:
            makeAlert(title: "Allow \"SwapMap\" to Access Your Location",
                      message: "Go to Settings > Screen Time > Content & Privacy Restrictions")
        case .authorizedAlways:
            break
        @unknown default:
            break
        }
    }
    
    private func centerViewOnUserLocation() {
        if let location = locationManager.location?.coordinate {
            let region = MKCoordinateRegion.init(center: location,
            latitudinalMeters: regionInMeters, longitudinalMeters: regionInMeters)
            mapView.setRegion(region, animated: true)
        }
    }
    
    private func startTrackingUserLocation() {
        mapView.showsUserLocation = true
        centerViewOnUserLocation()
        locationManager.startUpdatingLocation()
        previousLocation = getCenterLocation(for: mapView)
    }
    
    private func getCenterLocation(for mapView: MKMapView) -> CLLocation {
        let latitude = mapView.centerCoordinate.latitude
        let longitude = mapView.centerCoordinate.longitude
        
        return CLLocation(latitude: latitude, longitude: longitude)
        
    }
    
//    MARK: - Get Direction
    
    private func getDirections() {
        guard let location = locationManager.location?.coordinate else {
            let alert: () = makeAlert(title: "Current Location Not Available",
                      message: "Your current location can't be determined at this time.")
            return alert
        }
        
        let request = createDirectionRequest(from: location)
        let directions = MKDirections(request: request)
        resetMapView(withNew: directions)
        
        directions.calculate { [unowned self] (response, error) in
            guard let response = response else { return }
            
            for route in response.routes {
                self.mapView.addOverlay(route.polyline)
                self.mapView.setVisibleMapRect(route.polyline.boundingMapRect, animated: true)
            }
        }
    }
    
    private func createDirectionRequest(from coordinate: CLLocationCoordinate2D) -> MKDirections.Request {
        let destinationCoordinate       = getCenterLocation(for: mapView).coordinate
        let startingLocation            = MKPlacemark(coordinate: coordinate)
        let destination                 = MKPlacemark(coordinate: destinationCoordinate)
        
        let request                     = MKDirections.Request()
        request.source                  = MKMapItem(placemark: startingLocation)
        request.destination             = MKMapItem(placemark: destination)
        request.transportType           = .automobile
        request.requestsAlternateRoutes = true
        
        return request
    }
    
    private func resetMapView(withNew direction: MKDirections) {
        mapView.removeOverlays(mapView.overlays)
        directionsArray.append(direction)
        let _ = directionsArray.map { $0.cancel() }
    }
}

//    MARK: - Extensions

extension ViewController: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        checkLocationAuthorization()
    }
}

extension ViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        let center = getCenterLocation(for: mapView)
        let geoCoder = CLGeocoder()
        
        guard let previousLocation = self.previousLocation else { return }
        
        guard center.distance(from: previousLocation) > 50 else { return }
        self.previousLocation = center
        
        geoCoder.cancelGeocode()
        
        geoCoder.reverseGeocodeLocation(center) { [weak self] (placemarks, error) in
            guard let self = self else { return }
            
            guard let placemark = placemarks?.first else { return }
            
            let streetNumber = placemark.subThoroughfare ?? ""
            let streetName = placemark.thoroughfare ?? ""
            let city = placemark.locality ?? ""
            
            DispatchQueue.main.async {
                self.adressLabel.text = "\(streetNumber) \(streetName) \(city)"
            }
        }
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let render = MKPolylineRenderer(overlay: overlay as! MKPolyline)
        render.strokeColor = .systemYellow
        
        return render
    }
}
