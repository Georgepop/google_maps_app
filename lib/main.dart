import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;

const String kGoogleApiKey = "AIzaSyAOVYRIgupAurZup5y1PRh8Ismb1A3lLao";

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Maps Search v3',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MapSearchPage(),
    );
  }
}

class MapSearchPage extends StatefulWidget {
  const MapSearchPage({super.key});
  @override
  State<MapSearchPage> createState() => _MapSearchPageState();
}

class _MapSearchPageState extends State<MapSearchPage> {
  final Completer<GoogleMapController> _controller = Completer();
  LatLng _center = const LatLng(50.0755, 14.4378); // Prague default
  Marker? _marker;
  bool _loadingLocation = true;
  BitmapDescriptor? _customIcon;

  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _suggestions = [];
  bool _showSuggestions = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadCustomMarker();
    _determinePosition();
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _loadCustomMarker() async {
    try {
      final bytes = await rootBundle.load('assets/marker.png');
      final list = bytes.buffer.asUint8List();
      _customIcon = BitmapDescriptor.fromBytes(list);
    } catch (e) {
      _customIcon = null;
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final text = _searchController.text;
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (text.isEmpty) { setState(() { _suggestions = []; _showSuggestions = false; }); return; }
      await _fetchPlaceAutocomplete(text);
    });
  }

  Future<void> _fetchPlaceAutocomplete(String input) async {
    final url = Uri.https('maps.googleapis.com', '/maps/api/place/autocomplete/json', {
      'input': input,
      'key': kGoogleApiKey,
      'types': 'geocode',
      'components': 'country:cz' // restrict to Czechia; remove for worldwide
    });
    try {
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          _suggestions = data['predictions'] ?? [];
          _showSuggestions = _suggestions.isNotEmpty;
        });
      }
    } catch (e) {
      // ignore network errors silently
    }
  }

  Future<void> _selectSuggestion(dynamic prediction) async {
    final placeId = prediction['place_id'];
    final url = Uri.https('maps.googleapis.com', '/maps/api/place/details/json', {
      'place_id': placeId,
      'key': kGoogleApiKey,
      'fields': 'geometry,name,formatted_address'
    });
    try {
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final loc = data['result']['geometry']['location'];
        final lat = (loc['lat'] as num).toDouble();
        final lng = (loc['lng'] as num).toDouble();
        final pos = LatLng(lat, lng);
        // place marker but DO NOT change zoom level (no auto-zoom)
        _moveMarker(pos, title: data['result']['name'] ?? prediction['description']);
        _searchController.text = prediction['description'];
        setState(() { _showSuggestions = false; _suggestions = []; });
      }
    } catch (e) {
      // ignore
    }
  }

  void _moveMarker(LatLng pos, {String? title}) async {
    final currentZoom = await _getCurrentZoom();
    setState(() {
      _marker = Marker(
        markerId: const MarkerId('searched'),
        position: pos,
        infoWindow: InfoWindow(title: title ?? 'Location'),
        icon: _customIcon ?? BitmapDescriptor.defaultMarker,
      );
    });
    final controller = await _controller.future;
    // move camera to position but keep current zoom (no auto-zoom)
    controller.moveCamera(CameraUpdate.newCameraPosition(CameraPosition(target: pos, zoom: currentZoom)));
  }

  Future<double> _getCurrentZoom() async {
    try {
      final controller = await _controller.future;
      // There's no direct zoom getter; keep a sensible default
      return 12.0;
    } catch (e) {
      return 12.0;
    }
  }

  Future<void> _determinePosition() async {
    try {
      final status = await Permission.location.status;
      if (!status.isGranted) {
        final req = await Permission.location.request();
        if (!req.isGranted) {
          setState(() { _loadingLocation = false; });
          return;
        }
      }
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high).timeout(const Duration(seconds: 8));
      final latlng = LatLng(position.latitude, position.longitude);
      setState(() {
        _center = latlng;
        _loadingLocation = false;
        _marker = Marker(
          markerId: const MarkerId('me'),
          position: latlng,
          infoWindow: const InfoWindow(title: 'You are here'),
          icon: _customIcon ?? BitmapDescriptor.defaultMarker,
        );
      });
      final controller = await _controller.future;
      controller.moveCamera(CameraUpdate.newCameraPosition(CameraPosition(target: latlng, zoom: 12.0)));
    } catch (e) {
      setState(() { _loadingLocation = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Maps Search v3')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Material(
                  elevation: 2,
                  borderRadius: BorderRadius.circular(8),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search address...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () { _searchController.clear(); },
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                  ),
                ),
                if (_showSuggestions)
                  Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _suggestions.length,
                      itemBuilder: (context, idx) {
                        final p = _suggestions[idx];
                        return ListTile(
                          title: Text(p['structured_formatting']?['main_text'] ?? p['description']),
                          subtitle: Text(p['structured_formatting']?['secondary_text'] ?? ''),
                          onTap: () => _selectSuggestion(p),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  onMapCreated: (controller) {
                    if (!_controller.isCompleted) _controller.complete(controller);
                  },
                  initialCameraPosition: CameraPosition(target: _center, zoom: 12),
                  markers: _marker != null ? {_marker!} : {},
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  onTap: (latlng) => _moveMarker(latlng),
                ),
                if (_loadingLocation)
                  const Positioned(left: 16, top: 16, child: Card(child: Padding(padding: EdgeInsets.all(8), child: Text('Detecting location…')))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
