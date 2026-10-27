import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:mmmm/models/gift_model.dart';
import 'package:mmmm/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  final firestore = FirebaseFirestore.instance;
  final giftsCollection = 'gifts';
  
  print('Starting sync of ${predefinedGifts.length} gifts...');
  
  final batch = firestore.batch();
  for (var gift in predefinedGifts) {
    final docRef = firestore.collection(giftsCollection).doc(gift.id);
    batch.set(docRef, gift.toMap());
  }
  
  await batch.commit();
  print('Sync completed successfully!');
}
