import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:provider/provider.dart';

class Weather {
  final String cityName;
  final double temperature;
  final double maxTemperature;
  final double minTemperature;
  final String description;
  final DateTime dateTime;

  Weather({
    required this.cityName,
    required this.temperature,
    required this.maxTemperature,
    required this.minTemperature,
    required this.description,
    required this.dateTime,
  });

  factory Weather.fromJson(Map<String, dynamic> json) {
    return Weather(
      cityName: json['name'] ?? '',
      temperature: (json['main']['temp'] ?? 0.0).toDouble(),
      maxTemperature: (json['main']['temp_max'] ?? 0.0).toDouble(),
      minTemperature: (json['main']['temp_min'] ?? 0.0).toDouble(),
      description: (json['weather'][0]['description'] ?? '') as String,
      dateTime: DateTime.fromMillisecondsSinceEpoch(
        (json['dt'] ?? 0) * 1000,
        isUtc: true,
      ),
    );
  }
}

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: MyApp(),
    ),
  );
}

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  void setThemeMode(ThemeMode themeMode) {
    _themeMode = themeMode;
    notifyListeners();
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weather App',
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: Provider.of<ThemeProvider>(context).themeMode,
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Weather _currentWeather = Weather(
    cityName: '',
    temperature: 0.0,
    maxTemperature: 0.0,
    minTemperature: 0.0,
    description: '',
    dateTime: DateTime.now(),
  );
  List<Weather> _dailyForecast = [];
  final TextEditingController _cityController = TextEditingController();
  final String apiKey = '259d5c11d89422a265a02976aafcf0f3';
  double _fontSize = 16;
  bool _isCelsius = true;

  @override
  void initState() {
    super.initState();
    _fetchLocationAndWeather();
  }

  Future<void> _fetchWeather(String city) async {
    final response = await http.get(Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather?q=$city&appid=$apiKey'));

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      setState(() {
        _currentWeather = Weather.fromJson(data);
      });
    } else {
      print('Failed to load weather data. Status code: ${response.statusCode}');
      throw Exception('Failed to load weather data');
    }
  }

  Future<void> _fetchDailyForecast(String city) async {
    final response = await http.get(Uri.parse(
        'https://api.openweathermap.org/data/2.5/forecast?q=$city&appid=$apiKey'));

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      final List<dynamic> dataList = data['list'];
      final List<Weather> forecast = dataList.map((item) {
        return Weather(
          cityName: city,
          temperature: (item['main']['temp'] ?? 0.0).toDouble(),
          maxTemperature: (item['main']['temp_max'] ?? 0.0).toDouble(),
          minTemperature: (item['main']['temp_min'] ?? 0.0).toDouble(),
          description: (item['weather'][0]['description'] ?? '') as String,
          dateTime: DateTime.fromMillisecondsSinceEpoch(
            (item['dt'] ?? 0) * 1000,
            isUtc: true,
          ),
        );
      }).toList();

      setState(() {
        final DateTime now = DateTime.now();
        _dailyForecast = forecast.where((item) {
          return item.dateTime.isAfter(now) && item.dateTime.hour == 12;
        }).toList();
      });
    } else {
      print('Failed to load forecast data. Status code: ${response.statusCode}');
      throw Exception('Failed to load forecast data');
    }
  }

  Future<void> _fetchLocationAndWeather() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final String city = placemarks.first.locality ?? 'Unknown City';
        setState(() {
          _cityController.text = city;
        });
        _fetchWeather(city);
        _fetchDailyForecast(city);
      }
    } catch (e) {
      print('Error fetching location: $e');
    }
  }

  IconData _getWeatherIcon(String description) {
    switch (description.toLowerCase()) {
      case 'clear sky':
        return Icons.wb_sunny;
      case 'few clouds':
      case 'scattered clouds':
      case 'broken clouds':
        return Icons.cloud;
      case 'shower rain':
      case 'rain':
        return Icons.beach_access;
      case 'thunderstorm':
        return Icons.flash_on;
      case 'snow':
        return Icons.ac_unit;
      case 'mist':
        return Icons.cloud_queue;
      default:
        return Icons.error;
    }
  }

  void _toggleTemperatureUnit() {
    setState(() {
      _isCelsius = !_isCelsius;
    });
  }

  double _convertTemperature(double temperature) {
    if (_isCelsius) {
      return temperature - 273.15;
    } else {
      return (temperature - 273.15) * 9 / 5 + 32;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Weather App'),
        actions: [
          IconButton(
            icon: Icon(Icons.lightbulb),
            onPressed: () {
              Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _cityController,
                      decoration: InputDecoration(
                        labelText: 'Enter city name',
                        suffixIcon: IconButton(
                          icon: Icon(Icons.search),
                          onPressed: () {
                            _fetchWeather(_cityController.text);
                            _fetchDailyForecast(_cityController.text);
                          },
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.swap_horiz),
                    onPressed: _toggleTemperatureUnit,
                  ),
                ],
              ),
            ),
            _currentWeather != null
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Current Weather:',
                    style: TextStyle(
                      fontSize: _fontSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(
                    _getWeatherIcon(_currentWeather.description),
                    size: 50,
                  ),
                  Text(
                    'City: ${_currentWeather.cityName}',
                    style: TextStyle(fontSize: _fontSize),
                  ),
                  Text(
                    'Temperature: ${_convertTemperature(_currentWeather.temperature).toStringAsFixed(2)}°${_isCelsius ? 'C' : 'F'}',
                    style: TextStyle(fontSize: _fontSize),
                  ),
                  Text(
                    'Max Temperature: ${_convertTemperature(_currentWeather.maxTemperature).toStringAsFixed(2)}°${_isCelsius ? 'C' : 'F'}',
                    style: TextStyle(fontSize: _fontSize),
                  ),
                  Text(
                    'Min Temperature: ${_convertTemperature(_currentWeather.minTemperature).toStringAsFixed(2)}°${_isCelsius ? 'C' : 'F'}',
                    style: TextStyle(fontSize: _fontSize),
                  ),
                  Text(
                    'Description: ${_currentWeather.description}',
                    style: TextStyle(fontSize: _fontSize),
                  ),
                ],
              ),
            )
                : Center(
              child: CircularProgressIndicator(),
            ),
            _dailyForecast.isNotEmpty
                ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: 20),
                Text(
                  'Daily Forecast:',
                  style: TextStyle(
                    fontSize: _fontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  height: 150,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _dailyForecast.length,
                    itemBuilder: (context, index) {
                      var dailyWeather = _dailyForecast[index];
                      return Container(
                        width: 200,
                        padding: EdgeInsets.all(16),
                        margin: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _getWeatherIcon(dailyWeather.description),
                              size: 30,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'City: ${dailyWeather.cityName}',
                              style: TextStyle(fontSize: _fontSize - 2),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Temperature: ${_convertTemperature(dailyWeather.temperature).toStringAsFixed(2)}°${_isCelsius ? 'C' : 'F'}',
                              style: TextStyle(fontSize: _fontSize - 2),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Max Temperature: ${_convertTemperature(dailyWeather.maxTemperature).toStringAsFixed(2)}°${_isCelsius ? 'C' : 'F'}',
                              style: TextStyle(fontSize: _fontSize - 2),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Min Temperature: ${_convertTemperature(dailyWeather.minTemperature).toStringAsFixed(2)}°${_isCelsius ? 'C' : 'F'}',
                              style: TextStyle(fontSize: _fontSize - 2),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Description: ${dailyWeather.description}',
                              style: TextStyle(fontSize: _fontSize - 2),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            )
                : SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}
