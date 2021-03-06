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
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  List<MapBoxPlace> _places = [];
  late MapBoxPlace _chosenPlace;
  String hr = "";
  int counter = 0;
  final FlutterTts tts = FlutterTts();
  bool first_message = true;
  int max_hr = 0;

  var last = DateTime.now();
  var now = DateTime.now();

  @override
  void initState() {
    super.initState();

    WearableListener.listenForMessage((msg) {
      int temp = int.parse(msg);
      hr = "$temp";
      if (max_hr < temp) {
        max_hr = temp;
      }
      print(max_hr);
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
                  backgroundColor: Colors.white,
                  title: const Text(
                    'Pizza Time',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 25,
                        color: Colors.black),
                  ),
                ),
                body: Builder(builder: (context) {
                  if (_hasPermissions) {
                    return Column(
                      children: <Widget>[
                        Expanded(
                            child: _buildCompass(
                                MediaQuery.of(context).orientation)),
                        Container(
                            color: Colors.white,
                            padding: EdgeInsets.only(bottom: 10),
                            child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Material(
                                      color: Colors.white,
                                      child: Container(
                                          padding: EdgeInsets.all(10),
                                          alignment: Alignment.center,
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              alignment: Alignment.center,
                                              fixedSize: const Size(75, 75),
                                              shape: const CircleBorder(),
                                            ),
                                            child:
                                                Icon(Icons.qr_code_2, size: 45),
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      GenerateQRPage(
                                                          hr: "$max_hr"),
                                                ),
                                              );
                                            },
                                          ))),
                                  Material(
                                      child: Container(
                                          color: Colors.white,
                                          padding: EdgeInsets.only(left: 20),
                                          child: ElevatedButton(
                                            child: Icon(
                                                Icons.star_border_outlined,
                                                size: 45),
                                            style: ElevatedButton.styleFrom(
                                                alignment: Alignment.center,
                                                fixedSize: const Size(75, 75),
                                                shape: const CircleBorder()),
                                            onPressed: () {
                                              _boilerplate();
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      favoritesPage(),
                                                ),
                                              );
                                            },
                                          )))
                                ])),
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

  Widget _buildCompass(Orientation orientation) {
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

            if (orientation == Orientation.landscape) {
              return Row(children: [
                int.tryParse(hr) != null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 20, 50, 0),
                            child: Text(
                              _chosenPlace.toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 50, 60),
                            child: Text(
                              _distanceStr,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 20, 50, 0),
                            child: Text(
                              _chosenPlace.toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 25,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 50, 60),
                            child: Text(
                              _distanceStr,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 25,
                              ),
                            ),
                          ),
                        ],
                      ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Material(
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        elevation: 4.0,
                        child: Container(
                          padding: const EdgeInsets.all(30.0),
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            image: DecorationImage(
                              image: AssetImage('assets/pizza.png'),
                            ),
                            //shape: BoxShape.circle,
                          ),
                          child: Transform.rotate(
                            angle: (((temp * math.pi) / 180)),
                            child: Image.asset('assets/arrow.png'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                int.tryParse(hr) != null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Padding(
                              padding: const EdgeInsets.fromLTRB(50, 0, 10, 0),
                              child: Row(children: [
                                Text(
                                  hr + " bpm  ",
                                  //"100 bpm",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                  ),
                                ),
                                const Icon(
                                  Icons.favorite,
                                  color: Colors.red,
                                  size: 30,
                                )
                              ]))
                        ],
                      )
                    : const Text(""),
              ]);
            } else {
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
                Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Material(
                            shape: const CircleBorder(),
                            clipBehavior: Clip.antiAlias,
                            elevation: 4.0,
                            child: Container(
                              padding: const EdgeInsets.all(16.0),
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                image: DecorationImage(
                                  image: AssetImage('assets/pizza.png'),
                                ),
                                //shape: BoxShape.circle,
                              ),
                              child: Transform.rotate(
                                angle: (((temp * math.pi) / 180)),
                                child: Image.asset('assets/arrow.png'),
                              ),
                            ),
                          )
                        ])),
                int.tryParse(hr) != null
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(50, 50, 30, 10),
                              child: Row(children: [
                                Text(
                                  hr + " bpm  ",
                                  //"100 bpm",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                  ),
                                ),
                                const Icon(
                                  Icons.favorite,
                                  color: Colors.red,
                                  size: 30,
                                )
                              ]))
                        ],
                      )
                    : const Text(""),
              ]);
            }
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

  _boilerplate() async {
    await _addToFavorites();
  }

  _addToFavorites() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String key = 'favorites';
    final String value = _chosenPlace.toString();
    final List<String> favorites = (prefs.getStringList(key) ?? <String>[]);
    if (!favorites.contains(value)) {
      favorites.add(value);
      prefs.setStringList(key, favorites);
    }
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

class GenerateQRPage extends StatefulWidget {
  final String hr;
  const GenerateQRPage({Key? key, required this.hr}) : super(key: key);

  @override
  _GenerateQRPageState createState() => _GenerateQRPageState();
}

class _GenerateQRPageState extends State<GenerateQRPage> {
  TextEditingController controller = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'Discount Code',
          style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 25, color: Colors.black),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(50.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              QrImage(
                data: (int.parse(widget.hr) * 0.1).toString(),
                size: 300,
                gapless: true,
                embeddedImage: AssetImage('assets/pizza.png'),
                embeddedImageStyle: QrEmbeddedImageStyle(size: Size(80, 80)),
              ),
              Container(
                padding: const EdgeInsets.only(top: 10),
                child: const Text(
                  "Your Maximum Heart Rate was: ",
                  style: TextStyle(fontSize: 20),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(20),
                child: Text(
                  widget.hr,
                  style: TextStyle(fontSize: 30),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(20),
                child: Text(
                  "Discount: " + (int.parse(widget.hr) * 0.1).toString() + "%",
                  style: TextStyle(fontSize: 30),
                ),
              ),
              ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text('Go Back')),
            ],
          ),
        ),
      ),
    );
  }
}

class favoritesPage extends StatefulWidget {
  const favoritesPage({Key? key}) : super(key: key);

  @override
  _favoritesPage createState() => _favoritesPage();
}

class _favoritesPage extends State<favoritesPage> {
  TextEditingController controller = TextEditingController();

  Future<List<String>> _getFavorites() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String key = 'favorites';
    final List<String> favorites = (prefs.getStringList(key) ?? <String>[]);
    print(favorites);
    return favorites;
  }

  _boilerplate(String _chosenPlace) async {
    await _removeFromFavorites(_chosenPlace);
  }

  _removeFromFavorites(_chosenPlace) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String key = 'favorites';
    final String value = _chosenPlace;
    final List<String> favorites = (prefs.getStringList(key) ?? <String>[]);
    if (favorites.contains(value)) {
      favorites.remove(value);
      prefs.setStringList(key, favorites);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'Favorites',
          style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 25, color: Colors.black),
        ),
      ),
      body: SingleChildScrollView(
          child: Column(
        children: [
          SizedBox(
            height: 450,
            child: FutureBuilder<List<String>>(
              future: _getFavorites(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return ListView.builder(
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: Text(
                          snapshot.data![index],
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.delete),
                          onPressed: () {
                            _boilerplate(snapshot.data![index]);
                            setState(() {});
                          },
                        ),
                      );
                    },
                  );
                } else {
                  return Center(
                    child: CircularProgressIndicator(),
                  );
                }
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            child: ElevatedButton(
              child: const Text("Go Back"),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ),
        ],
      )),
    );
  }
}
