import 'package:silag/models/hotline_model.dart';

class HotlineService {
  final List<HotlineModel> _hotlines = [
    HotlineModel(id: 1, name: 'Valenzuela City DRRMO', number: '8352-5000'),
    HotlineModel(id: 2, name: 'Valenzuela City Police', number: '8352-4000'),
    HotlineModel(
      id: 3,
      name: 'Valenzuela City Fire Department',
      number: '8292-3519',
    ),
  ];

  Future<List<HotlineModel>> fetchHotlines() async {
    await Future.delayed(Duration(milliseconds: 200)); // Simulate network delay
    return _hotlines;
  }

  Future<void> addHotline(String name, String number) async {
    await Future.delayed(Duration(milliseconds: 200)); // Simulate network delay
    final newHotline = HotlineModel(
      id: _hotlines.length + 1,
      name: name,
      number: number,
    );
    _hotlines.add(newHotline);
  }
}
