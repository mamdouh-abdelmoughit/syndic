import 'package:flutter/material.dart';
import 'package:syndic_app/pages/Depense_page.dart';
import 'resident_page.dart';

class FirstPage extends StatelessWidget {
  const FirstPage
({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion Syndic'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ResidentPage(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                minimumSize: const Size(200, 50),
              ),
              child: const Text('Resident', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DepensePage(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                minimumSize: const Size(200, 50),
              ),
              child: const Text('Depense', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(height: 20),
 /*           ElevatedButton(
              onPressed: () {
                // TODO: Navigate to Divers page
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                minimumSize: const Size(200, 50),
              ),
              child: const Text('Divers', style: TextStyle(fontSize: 18)),
            ),*/
          ],
        ),
      ),
    );
  }
}
