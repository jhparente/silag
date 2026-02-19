import 'package:silag/models/sensor_model.dart';

class SensorService {
  Future<List<SensorModel>> fetchSensors() async {
    await Future.delayed(Duration(milliseconds: 80)); // Simulate network delay

    return [
      // For ultrasonic sensors:
      // normal, warning, danger, critical

      // For float sensors:
      // normal, rising
      SensorModel.ultrasonic(
        id: '1',
        name: 'Sensor 1',
        waterLevel: 3.0,
        status: 'Danger',
        location: 'Dalandanan Elementary School',
      ),
      SensorModel.float(
        id: '2',
        name: 'Sensor 2',
        isRising: true,
        status: 'Rising',
        location: 'Dalandanan Elementary School',
      ),
      SensorModel.ultrasonic(
        id: '3',
        name: 'Sensor 3',
        waterLevel: 0,
        status: 'Normal',
        location: '7/11 Dalandanan',
      ),
      SensorModel.float(
        id: '4',
        name: 'Sensor 4',
        isRising: false,
        status: 'Normal',
        location: '7/11 Dalandanan',
      ),
    ];
  }
}
