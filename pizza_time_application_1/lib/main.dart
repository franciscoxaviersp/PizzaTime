import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
//import 'package:google_maps_webservice/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
// ignore: import_of_legacy_library_into_null_safe
//import 'package:google_maps_webservice/places.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mapbox_search/mapbox_search.dart';
import 'package:wearable_communicator/wearable_communicator.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:number_to_words/number_to_words.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  const MyApp({
    Key? key,
  }) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _hasPermissions = false;
  CompassEvent? _lastRead;
  DateTime? _lastReadAt;
  List<MapBoxPlace> _places = [];
  late MapBoxPlace _chosenPlace;
  String hr = "";
  int counter = 0;
  final FlutterTts tts = FlutterTts();

  var last = DateTime.now();
  var now = DateTime.now();

  @override
  void initState() {
    super.initState();

    WearableListener.listenForMessage((msg) {
      hr = msg;
      print(hr);
    });

    _fetchPermissionStatus();
    tts.setLanguage('it');
    tts.setSpeechRate(0.6);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _getLocationAndRestaurant(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasData) {
            _places = snapshot.data as List<MapBoxPlace>;
            _chosenPlace = _chooseRandomPlace();
            return MaterialApp(
              home: Scaffold(
                backgroundColor: Colors.white,
                appBar: AppBar(
                  title: const Text('Pizza Time'),
                ),
                body: Builder(builder: (context) {
                  if (_hasPermissions) {
                    return Column(
                      children: <Widget>[
                        //_buildManualReader(),
                        Expanded(child: _buildCompass()),
                      ],
                    );
                  } else {
                    return _buildPermissionSheet();
                  }
                }),
              ),
            );
          } else {
            return const MaterialApp(
                home: Center(
              child: CircularProgressIndicator(),
            ));
          }
        }
        return const MaterialApp(
            home: Center(
          child: CircularProgressIndicator(),
        ));
      },
    );
  }

  Widget _buildManualReader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: <Widget>[
          ElevatedButton(
            child: const Text('Read Value'),
            onPressed: () async {
              final CompassEvent tmp = await FlutterCompass.events!.first;
              setState(() {
                _lastRead = tmp;
                _lastReadAt = DateTime.now();
              });
            },
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '$_lastRead',
                    style: Theme.of(context).textTheme.caption,
                  ),
                  Text(
                    '$_lastReadAt',
                    style: Theme.of(context).textTheme.caption,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompass() {
    return StreamBuilder<CompassEvent>(
      stream: FlutterCompass.events,
      builder: (context1, snapshot1) {
        if (snapshot1.hasError) {
          return Text('Error reading position: ${snapshot1.error}');
        }

        if (snapshot1.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        return StreamBuilder<Position>(
          stream: Geolocator.getPositionStream(),
          builder: (context2, snapshot2) {
            if (snapshot2.hasError) {
              return Text('Error reading heading: ${snapshot1.error}');
            }
            if (snapshot2.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            //get heading relative to north
            double? direction = snapshot1.data!.heading;

            double my_lat = snapshot2.data!.latitude;
            double my_long = snapshot2.data!.longitude;
            double target_lat =
                _chosenPlace.geometry?.coordinates![1] as double;
            double target_long =
                _chosenPlace.geometry?.coordinates![0] as double;
            /*
            my_lat = 40.4688500;
            my_long = -8.7269200;
            target_lat = 40.45687;
            target_long = -8.72692;*/ /*
            print("My lat: $my_lat");
            print("My long: $my_long");
            print("Target lat: $target_lat");
            print("Target long: $target_long");
            print(_chosenPlace);*/
            var _distance = GeolocatorPlatform.instance
                .distanceBetween(my_lat, my_long, target_lat, target_long)
                .toInt();

            var _distanceStr = _distance.toString() + " m";
            now = DateTime.now();

            //print(now.difference(last).inSeconds);
            if (now.difference(last).inSeconds >= 10) {
              print("AAAAAAAAAAAAAAAAAAAAA");
              last = now;
              tts.speak(NumberToWord().convert('en-in', _distance) +
                  " meters left to " +
                  _chosenPlace.toString());
            }

            my_lat = my_lat * math.pi / 180;
            my_long = my_long * math.pi / 180;
            target_lat = target_lat * math.pi / 180;
            target_long = target_long * math.pi / 180;

            // if direction is null, then device does not support this sensor
            // show error message
            if (direction == null || _chosenPlace == null) {
              return const Center(
                child: Text("Device does not have sensors !"),
              );
            }

            //calculate bearing
            //Bearing can be defined as direction or an angle, between the north-south line of
            //earth or meridian and the line connecting the target and the reference point
            var bearing;
            var temp;

            bearing = Geolocator.bearingBetween(
                my_lat, my_long, target_lat, target_long);
            /*
            print("Direction: $direction");
            print("Bearing: $bearing");*/
            temp = direction;
            temp = bearing - direction;

            return Column(children: [
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 40, 20, 0),
                    child: Text(
                      _chosenPlace.toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 30,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 60),
                    child: Text(
                      _distanceStr,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 50,
                      ),
                    ),
                  ),
                ],
              ),
              Material(
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                elevation: 4.0,
                child: Container(
                  padding: const EdgeInsets.all(16.0),
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                  ),
                  child: Transform.rotate(
                    angle: (((temp * math.pi) / 180)),
                    child: Image.asset('assets/arrow.png'),
                  ),
                ),
              )
            ]);
          },
        );
      },
    );
  }

  Widget _buildPermissionSheet() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Text('Location Permission Required'),
          ElevatedButton(
            child: const Text('Request Permissions'),
            onPressed: () {
              Permission.locationWhenInUse.request().then((ignored) {
                _fetchPermissionStatus();
              });
            },
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            child: const Text('Open App Settings'),
            onPressed: () {
              openAppSettings().then((opened) {
                //
              });
            },
          )
        ],
      ),
    );
  }

  Future<List<MapBoxPlace>> _getLocationAndRestaurant() async {
    var _position = await Geolocator.getCurrentPosition();

    /*
    GoogleMapsPlaces googlePlace =
        GoogleMapsPlaces(apiKey: "AIzaSyAdaPNE1EoOUJBC2whLS7gESGoBUhJaPbI");
    PlacesSearchResponse _response = await googlePlace.searchNearbyWithRadius(
        Location(_position.latitude, _position.longitude), 100000,
        type: "restaurant");

    Set<Location> _restaurantLocations = _response.results
        .map((result) => Location(
            result.geometry.location.lat, result.geometry.location.lng))
        .toSet();
    print(_restaurantLocations);*/
    var placesService = PlacesSearch(
      apiKey:
          "pk.eyJ1IjoieGljbzE0MzMiLCJhIjoiY2t2ZTB4M2ZjMWViZzMxcGdwajhvMTBzdiJ9.AiHPWBayhQ2w0qGrMoZguQ",
      country: "PT",
      limit: 5,
    );

    List<MapBoxPlace> places = await placesService.getPlaces(
      "pizzaria",
      /* test fixed on Aveiro
      location: Location(
        lat: 40.631718,
        lng: -8.658655,
      ), */
      location: Location(
        lat: _position.latitude,
        lng: _position.longitude,
      ),
    ) as List<MapBoxPlace>;

    //print(places);

    for (var i = 0; i < places.length; i++) {
      //print(places[i].geometry?.coordinates);
    }
    return places;
  }

  //sets a new random target place
  MapBoxPlace _chooseRandomPlace() {
    final _random = new math.Random();
    return _places[_random.nextInt(_places.length)];
  }

  void _fetchPermissionStatus() {
    Permission.locationWhenInUse.status.then((status) {
      if (mounted) {
        setState(() => _hasPermissions = status == PermissionStatus.granted);
      }
    });
  }
}
