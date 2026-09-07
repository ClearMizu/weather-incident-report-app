import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class WeatherPage extends StatefulWidget {
  const WeatherPage({super.key});

  @override
  State<WeatherPage> createState() => _WeatherPageState();
}

class _WeatherPageState extends State<WeatherPage> {
  bool _isLoading = false;
  String _errorMessage = '';

  // Weather State (Bangkok)
  double? _temperature;
  double? _windSpeed;
  int? _weatherCode;

  // Air Quality & Forecast State
  double? _pm25;
  int? _usAqi;
  double? _todayMaxTemp;
  double? _todayPrecipitation;
  double? _todayUvIndex;

  List<Map<String, dynamic>> _dailyForecast = [];

  @override
  void initState() {
    super.initState();
    _fetchWeatherData();
  }

  Future<void> _fetchWeatherData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // 1. Fetch Live Weather + Daily Forecast for Bangkok from Open-Meteo Public API
      final weatherUri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?'
        'latitude=13.75&longitude=100.50'
        '&current_weather=true'
        '&daily=temperature_2m_max,temperature_2m_min,precipitation_sum,uv_index_max'
        '&timezone=Asia%2FBangkok',
      );

      // 2. Fetch Live Air Quality for Bangkok from Open-Meteo Air Quality Public API
      final airQualityUri = Uri.parse(
        'https://air-quality-api.open-meteo.com/v1/air-quality?'
        'latitude=13.75&longitude=100.50'
        '&current=pm2_5,us_aqi',
      );

      final responses = await Future.wait([
        http.get(weatherUri),
        http.get(airQualityUri),
      ]);

      if (responses[0].statusCode == 200) {
        final weatherData = json.decode(responses[0].body);
        final currentWeather = weatherData['current_weather'];
        _temperature = (currentWeather['temperature'] as num?)?.toDouble();
        _windSpeed = (currentWeather['windspeed'] as num?)?.toDouble();
        _weatherCode = (currentWeather['weathercode'] as num?)?.toInt();

        final daily = weatherData['daily'];
        if (daily != null) {
          final dates = List<String>.from(daily['time'] ?? []);
          final maxTemps = List<num>.from(daily['temperature_2m_max'] ?? []);
          final minTemps = List<num>.from(daily['temperature_2m_min'] ?? []);
          final rain = List<num>.from(daily['precipitation_sum'] ?? []);
          final uv = List<num>.from(daily['uv_index_max'] ?? []);

          if (maxTemps.isNotEmpty) {
            _todayMaxTemp = maxTemps[0].toDouble();
            _todayPrecipitation = rain.isNotEmpty ? rain[0].toDouble() : 0.0;
            _todayUvIndex = uv.isNotEmpty ? uv[0].toDouble() : 0.0;
          }

          _dailyForecast = [];
          for (int i = 0; i < dates.length && i < 3; i++) {
            _dailyForecast.add({
              'date': dates[i],
              'maxTemp': maxTemps[i].toDouble(),
              'minTemp': minTemps[i].toDouble(),
              'rain': rain[i].toDouble(),
            });
          }
        }
      } else {
        _errorMessage = 'Failed to fetch Bangkok weather.';
      }

      if (responses[1].statusCode == 200) {
        final airData = json.decode(responses[1].body);
        final currentAir = airData['current'];
        if (currentAir != null) {
          _pm25 = (currentAir['pm2_5'] as num?)?.toDouble();
          _usAqi = (currentAir['us_aqi'] as num?)?.toInt();
        }
      }
    } catch (e) {
      _errorMessage = 'Error loading live API data: $e';
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getWeatherConditionText(int? code) {
    if (code == null) return 'Unknown';
    if (code == 0) return 'Clear Sky ☀️';
    if (code >= 1 && code <= 3) return 'Partly Cloudy ⛅';
    if (code >= 45 && code <= 48) return 'Foggy 🌫️';
    if (code >= 51 && code <= 67) return 'Rainy 🌧️';
    if (code >= 80 && code <= 82) return 'Showers 🌧️';
    if (code >= 95) return 'Thunderstorm ⛈️';
    return 'Cloudy ☁️';
  }

  List<Widget> _buildRealAdvisories() {
    List<Widget> list = [];

    // Air Quality Advisory
    if (_pm25 != null) {
      final isHighPm = _pm25! > 35;
      list.add(
        Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: Icon(
              Icons.air,
              color: isHighPm ? Colors.orange : Colors.green,
            ),
            title: Text(
              isHighPm ? 'Air Quality Warning (PM2.5)' : 'Air Quality Status',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: Text(
              'Bangkok PM2.5: ${_pm25!.toStringAsFixed(1)} µg/m³ (AQI: ${_usAqi ?? "N/A"}). '
              '${isHighPm ? "Wear N95 masks during outdoor field work." : "Air quality is suitable for outdoor operations."}',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ),
      );
    }

    // Heat & UV Advisory
    if (_todayMaxTemp != null || _todayUvIndex != null) {
      final isHot = (_todayMaxTemp ?? 0) > 33 || (_todayUvIndex ?? 0) > 7;
      list.add(
        Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: Icon(
              Icons.wb_sunny_outlined,
              color: isHot ? Colors.red : Colors.orange,
            ),
            title: const Text(
              'Heat & UV Exposure Advisory',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: Text(
              'Forecast Max: ${_todayMaxTemp?.toStringAsFixed(1) ?? "33"}°C, UV Index: ${_todayUvIndex?.toStringAsFixed(1) ?? "High"}. '
              'Stay hydrated and take rest breaks during peak afternoon hours.',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ),
      );
    }

    // Rain Advisory
    if (_todayPrecipitation != null) {
      final isRainy = _todayPrecipitation! > 1.0;
      list.add(
        Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: Icon(
              Icons.umbrella,
              color: isRainy ? Colors.blue : Colors.grey,
            ),
            title: const Text(
              'Precipitation & Flood Caution',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: Text(
              'Expected Rain Today: ${_todayPrecipitation!.toStringAsFixed(1)} mm. '
              '${isRainy ? "Carry rain gear and watch for localized road flooding in low-lying Bangkok districts." : "Low rainfall expected today."}',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ),
      );
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Field Weather & Safety',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _isLoading ? null : _fetchWeatherData,
                tooltip: 'Refresh Weather',
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(30.0),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_errorMessage.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.red.shade100,
              child: Column(
                children: [
                  Text(_errorMessage, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _fetchWeatherData,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          else ...[
            // Main Weather Card
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.redAccent, size: 28),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bangkok, Thailand 🇹🇭',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade900,
                              ),
                            ),
                            const Text(
                              'Live Weather Conditions',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 4),
                    const Row(
                      children: [
                        Icon(Icons.map, size: 16, color: Colors.grey),
                        SizedBox(width: 4),
                        Text(
                          'Bangkok Metropolis (13.75°N, 100.50°E)',
                          style: TextStyle(fontSize: 13, color: Colors.black87),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Condition: ${_getWeatherConditionText(_weatherCode)}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Current Temp: ${_temperature != null ? "$_temperature °C" : "N/A"}',
                      style: const TextStyle(fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Wind Speed: ${_windSpeed != null ? "$_windSpeed km/h" : "N/A"}',
                      style: const TextStyle(fontSize: 15),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Source: Open-Meteo Public API',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Live Field Advisories Section
            const Text(
              'Bangkok Field Advisories',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            ..._buildRealAdvisories(),

            const SizedBox(height: 20),

            // 3-Day Forecast Section
            if (_dailyForecast.isNotEmpty) ...[
              const Text(
                '3-Day Outlook (Bangkok)',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: _dailyForecast.map((day) {
                  return Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          children: [
                            Text(
                              day['date'],
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${day['maxTemp']}° / ${day['minTemp']}°',
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '💧 ${day['rain']} mm',
                              style: const TextStyle(fontSize: 11, color: Colors.blue),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
