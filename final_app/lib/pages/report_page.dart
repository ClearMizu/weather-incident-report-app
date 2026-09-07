import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FieldReport {
  final String title;
  final String description;
  final String? imagePath;
  final double? latitude;
  final double? longitude;
  final DateTime timestamp;

  FieldReport({
    required this.title,
    required this.description,
    this.imagePath,
    this.latitude,
    this.longitude,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'imagePath': imagePath,
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': timestamp.toIso8601String(),
      };

  factory FieldReport.fromJson(Map<String, dynamic> json) => FieldReport(
        title: json['title'] ?? '',
        description: json['description'] ?? '',
        imagePath: json['imagePath'],
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        timestamp: json['timestamp'] != null
            ? DateTime.parse(json['timestamp'])
            : DateTime.now(),
      );
}

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  // Camera State
  XFile? _capturedImage;
  final ImagePicker _picker = ImagePicker();

  // GPS Sensor State
  double? _latitude;
  double? _longitude;
  String _locationStatus = 'No location attached';
  bool _isLocating = false;

  // Submitted Reports List
  final List<FieldReport> _submittedReports = [];

  @override
  void initState() {
    super.initState();
    _loadSavedReports();
  }

  Future<void> _loadSavedReports() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? reportsJson = prefs.getString('saved_field_reports');
      if (reportsJson != null) {
        final List<dynamic> decoded = json.decode(reportsJson);
        setState(() {
          _submittedReports.clear();
          _submittedReports.addAll(
            decoded.map((item) => FieldReport.fromJson(item)).toList(),
          );
        });
      }
    } catch (e) {
      debugPrint('Error loading saved reports: $e');
    }
  }

  Future<void> _saveReportsToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encoded = json.encode(
        _submittedReports.map((r) => r.toJson()).toList(),
      );
      await prefs.setString('saved_field_reports', encoded);
    } catch (e) {
      debugPrint('Error saving reports: $e');
    }
  }

  Future<void> _clearAllReports() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_field_reports');
    setState(() {
      _submittedReports.clear();
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All saved reports cleared.')),
      );
    }
  }

  void _deleteReport(int index) {
    setState(() {
      _submittedReports.removeAt(index);
    });
    _saveReportsToStorage();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report deleted.')),
    );
  }

  void _editReport(int index) {
    final report = _submittedReports[index];
    final editTitleController = TextEditingController(text: report.title);
    final editDescController = TextEditingController(text: report.description);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Report'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: editTitleController,
                decoration: const InputDecoration(labelText: 'Incident Title'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: editDescController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Details / Description'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final newTitle = editTitleController.text.trim();
                if (newTitle.isNotEmpty) {
                  setState(() {
                    _submittedReports[index] = FieldReport(
                      title: newTitle,
                      description: editDescController.text.trim(),
                      imagePath: report.imagePath,
                      latitude: report.latitude,
                      longitude: report.longitude,
                      timestamp: report.timestamp,
                    );
                  });
                  _saveReportsToStorage();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Report updated.')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  // Camera Action
  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 800,
      );
      if (photo != null) {
        setState(() {
          _capturedImage = photo;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera error: $e')),
        );
      }
    }
  }

  // Gallery Fallback
  Future<void> _pickGallery() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
      );
      if (photo != null) {
        setState(() {
          _capturedImage = photo;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gallery error: $e')),
        );
      }
    }
  }

  // GPS Sensor Action
  Future<void> _getGpsLocation() async {
    setState(() {
      _isLocating = true;
      _locationStatus = 'Checking GPS...';
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationStatus = 'GPS service disabled. Enable location.';
          _isLocating = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _locationStatus = 'Permission denied.';
            _isLocating = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationStatus = 'Permission permanently denied.';
          _isLocating = false;
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _locationStatus =
            'Lat: ${_latitude!.toStringAsFixed(5)}, Lon: ${_longitude!.toStringAsFixed(5)}';
      });
    } catch (e) {
      setState(() {
        _locationStatus = 'Location error: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLocating = false;
        });
      }
    }
  }

  void _submitReport() {
    final title = _titleController.text.trim();
    final desc = _descController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an incident title.')),
      );
      return;
    }

    final newReport = FieldReport(
      title: title,
      description: desc.isNotEmpty ? desc : 'No description provided.',
      imagePath: _capturedImage?.path,
      latitude: _latitude,
      longitude: _longitude,
      timestamp: DateTime.now(),
    );

    setState(() {
      _submittedReports.insert(0, newReport);
      // Reset form
      _titleController.clear();
      _descController.clear();
      _capturedImage = null;
      _latitude = null;
      _longitude = null;
      _locationStatus = 'No location attached';
    });

    _saveReportsToStorage();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Field report submitted and saved locally!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'New Incident Report',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // Title & Description Inputs
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Incident Title (e.g. Fallen Tree, Pothole)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _descController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Details / Description',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // Camera Photo Input
          const Text(
            'Photo Evidence (Camera)',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Container(
            height: 160,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey.shade50,
            ),
            child: _capturedImage == null
                ? const Center(
                    child: Text(
                      'No photo captured',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : kIsWeb
                    ? Image.network(_capturedImage!.path, fit: BoxFit.cover)
                    : Image.file(File(_capturedImage!.path), fit: BoxFit.cover),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _takePhoto,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Take Photo'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickGallery,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Gallery'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // GPS Sensor Input
          const Text(
            'Location Sensor (GPS)',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  _locationStatus,
                  style: TextStyle(
                    color: _latitude != null ? Colors.green.shade800 : Colors.black87,
                    fontWeight: _latitude != null ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _isLocating ? null : _getGpsLocation,
                icon: _isLocating
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location),
                label: const Text('Get GPS'),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Submit Button
          SizedBox(
            height: 46,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
              ),
              onPressed: _submitReport,
              child: const Text('Submit Field Report', style: TextStyle(fontSize: 16)),
            ),
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 8),

          // Submitted Reports Feed
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Submitted Reports (${_submittedReports.length})',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              if (_submittedReports.isNotEmpty)
                TextButton.icon(
                  onPressed: _clearAllReports,
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                  label: const Text('Clear All', style: TextStyle(color: Colors.red)),
                ),
            ],
          ),
          const SizedBox(height: 8),

          if (_submittedReports.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('No reports submitted yet.', style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            ..._submittedReports.asMap().entries.map((entry) {
              final index = entry.key;
              final report = entry.value;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              report.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                            onPressed: () => _editReport(index),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'Edit Report',
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                            onPressed: () => _deleteReport(index),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'Delete Report',
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(report.description),
                      if (report.latitude != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.location_on, size: 14, color: Colors.red),
                            const SizedBox(width: 4),
                            Text(
                              'GPS: ${report.latitude!.toStringAsFixed(5)}, ${report.longitude!.toStringAsFixed(5)}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                      if (report.imagePath != null) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: SizedBox(
                            height: 120,
                            width: double.infinity,
                            child: kIsWeb
                                ? Image.network(report.imagePath!, fit: BoxFit.cover)
                                : Image.file(File(report.imagePath!), fit: BoxFit.cover),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
