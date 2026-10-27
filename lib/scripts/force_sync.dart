import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../models/gift_model.dart';
import '../firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  final firestore = FirebaseFirestore.instance;
  final giftsCollection = 'gifts';
  
  print('Deleting existing gifts...');
  final existing = await firestore.collection(giftsCollection).get();
  for (var doc in existing.docs) {
    await doc.reference.delete();
  }
  
  print('Syncing ${predefinedGifts.length} gifts...');
  for (var gift in predefinedGifts) {
    await firestore.collection(giftsCollection).doc(gift.id).set(gift.toMap());
    print('Added: ${gift.name}');
  }
  
  print('Sync completed!');
}
