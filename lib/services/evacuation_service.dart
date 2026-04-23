import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:silag/models/evacuation_model.dart'; // Double-check this import path!
import 'api_config.dart';

class EvacuationService {
  Uri _buildUri(
    String path, {
    String? version,
    Map<String, dynamic>? queryParameters,
  }) {
    return ApiConfig.uri(
      path,
      version: version,
      queryParameters: queryParameters,
    );
  }

  Future<List<EvacuationModel>> fetchEvacuationCenters() async {
    try {
      // 1. Point exactly to your FastAPI GET route
      final url = _buildUri('evacuation_sites');

      // 2. Make the network request
      final response = await http.get(url);

      if (response.statusCode == 200) {
        // 3. Decode the raw string from FastAPI into a Dart Map
        final jsonResponse = jsonDecode(response.body);

        // 4. Extract the "data" list from your backend's {"status": "success", "data": [...]} response
        final List<dynamic> dataList = jsonResponse['data'];

        // 5. Loop through the list, run your translator, and return the clean Flutter models!
        return dataList.map((json) => EvacuationModel.fromJson(json)).toList();
      } else {
        print(
          "Failed to fetch evacuation sites. Status Code: ${response.statusCode}",
        );
        return []; // Return empty list if the database request fails
      }
    } catch (e) {
      print("Network error fetching evacuation sites: $e");
      return []; // Return empty list if FastAPI is turned off
    }
  }
}
