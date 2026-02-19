import 'package:silag/models/evacuation_model.dart';

class EvacuationService {
  final List<EvacuationModel> _sites = [
    EvacuationModel(
      id: '1',
      location: 'Santos Encarnacion E/S',
      address: '123 Dalandanan St, Valenzuela City',
      imageUrl:
          'https://lh3.googleusercontent.com/proxy/jJr2PqTnE33RHnUpcV4ng_LTR8BcpLlPULg68plCGtQJHbl8qDJiSZ3RiXA7f3x38rUJ7Yp1bEb81dVFmqVkLFjldFnb3cbxiB7WUcahA1IezrJwlHmb2cVL1aKxdnoZEAkRK93_vyBkVrq5YpiHvs25Bm8Zd2qv_sMwtA=s1360-w1360-h1020-rw',
      latitude: 14.70477,
      longitude: 120.96431,
    ),
    EvacuationModel(
      id: '2',
      location: 'Valenzuela City Astrodome',
      address: '456 Valenzuela Ave, Valenzuela City',
      imageUrl:
          'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcRK7N63TGomaKnj9TzzllLU4u0lnsj9RI2slg&s',
      latitude: 14.709100762481082,
      longitude: 120.9575183245075,
    ),
  ];

  Future<List<EvacuationModel>> fetchEvacuationCenters() async {
    await Future.delayed(Duration(milliseconds: 200)); // Simulate network delay
    return _sites;
  }
}
