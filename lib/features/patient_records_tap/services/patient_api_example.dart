// import 'package:flutter/material.dart';
// import '../services/patient_api_service.dart';
// import '../../patient_detail/model/patient_vital_signs.dart';
// import '../../edit_patient_info/model/patient_info_model.dart';

// /// Example: How to manually send patient data to API
// ///
// /// This is for testing purposes. In production, the data is sent
// /// automatically from patient_records_screen.dart
// class PatientApiExample {
//   /// Send a manual test request to the API
//   static Future<void> testApiCall() async {
//     // Create sample patient info
//     final patientInfo = PatientInfo(
//       deviceId: 'TEST_001',
//       patientName: 'Ahmed Test',
//       age: 30,
//       gender: Gender.male,
//       chronicDiseases: ['السكري', 'ارتفاع ضغط الدم'],
//       notes: 'Patient shows mild symptoms',
//       createdAt: DateTime.now(),
//       updatedAt: DateTime.now(),
//     );

//     // Create sample vital signs
//     final vitalSigns = PatientVitalSigns(
//       deviceId: 'TEST_001',
//       patientName: 'Ahmed Test',
//       temperature: 36.8,
//       heartRate: 72,
//       respiratoryRate: 18,
//       bloodPressure: {'systolic': 120, 'diastolic': 80},
//       spo2: 97,
//       timestamp: DateTime.now(),
//       ecgReadings: [
//         EcgReading(value: 0.1, timestamp: DateTime.now()),
//         EcgReading(value: 0.2, timestamp: DateTime.now()),
//         EcgReading(value: 0.3, timestamp: DateTime.now()),
//         EcgReading(value: 0.4, timestamp: DateTime.now()),
//       ],
//       isDeviceConnected: true,
//       lastDataReceived: DateTime.now(),
//     );

//     // Send to API
//     debugPrint('🧪 Testing API call...');
//     final result = await PatientApiService.sendToApi(
//       patientInfo: patientInfo,
//       vitalSigns: vitalSigns,
//       forceUpdate: true, // Force send even if data didn't change
//     );

//     if (result != null && result.containsKey('error')) {
//       debugPrint('❌ Test failed: ${result['error']}');
//     } else if (result != null) {
//       debugPrint('✅ Test succeeded: $result');
//     } else {
//       debugPrint('⚠️  No response from API');
//     }
//   }

//   /// Reset the API service cache
//   /// This allows sending the same data again (useful for testing)
//   static void resetApiCache() {
//     PatientApiService.resetCache();
//     debugPrint('🔄 API cache reset');
//   }

//   /// Example widget that shows how to use the service in a button
//   static Widget buildTestButton(BuildContext context) {
//     return ElevatedButton.icon(
//       onPressed: () async {
//         await testApiCall();
//       },
//       icon: const Icon(Icons.send),
//       label: const Text('اختبار إرسال البيانات للـ API'),
//     );
//   }
// }
