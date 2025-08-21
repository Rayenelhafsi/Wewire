# Guide de Configuration Firebase pour le Système de Communication Maintenance

## Étape 1: Créer un Projet Firebase

1. Allez sur [Firebase Console](https://console.firebase.google.com/)
2. Cliquez sur "Créer un projet"
3. Suivez les étapes de configuration
4. Activez les services suivants:
   - Authentication
   - Cloud Firestore
   - Cloud Storage
   - Cloud Messaging

## Étape 2: Configuration Flutter

### 1. Installation des dépendances
```bash
flutter pub add firebase_core
flutter pub add firebase_auth
flutter pub add cloud_firestore
flutter pub add firebase_storage
flutter pub add firebase_messaging
```

### 2. Configuration des plateformes

#### Android
1. Téléchargez `google-services.json` depuis Firebase Console
2. Placez-le dans `android/app/`
3. Modifiez `android/build.gradle`:
```gradle
buildscript {
    dependencies {
        classpath 'com.google.gms:google-services:4.3.15'
    }
}
```
4. Modifiez `android/app/build.gradle`:
```gradle
apply plugin: 'com.google.gms.google-services'
```

#### iOS
1. Téléchargez `GoogleService-Info.plist` depuis Firebase Console
2. Placez-le dans `ios/Runner/`
3. Modifiez `ios/Runner/AppDelegate.swift`:
```swift
import Firebase
FirebaseApp.configure()
```

#### Web
1. Ajoutez les scripts Firebase dans `web/index.html`:
```html
<script src="https://www.gstatic.com/firebasejs/9.0.0/firebase-app.js"></script>
<script src="https://www.gstatic.com/firebasejs/9.0.0/firebase-firestore.js"></script>
```

## Étape 3: Configuration Firestore

### Structure des Collections

#### Collection: `operators`
```json
{
  "matricule": "OP001",
  "name": "Ahmed Benali",
  "savedPhrases": ["Problème moteur", "Arrêt d'urgence"],
  "assignedMachines": ["MCH001", "MCH002"],
  "workStartTime": "2024-01-15T08:00:00Z",
  "workEndTime": "2024-01-15T17:00:00Z",
  "isCurrentlyWorking": true
}
```

#### Collection: `technicians`
```json
{
  "matricule": "TECH001",
  "name": "Youssef El Amrani",
  "specializations": ["Mécanique", "Électronique"],
  "isAvailable": true,
  "assignedIssues": ["ISS001", "ISS002"]
}
```

#### Collection: `machines`
```json
{
  "id": "MCH001",
  "reference": "REF-2024-001",
  "name": "Machine CNC 1",
  "location": "Atelier A",
  "status": "operational",
  "commonIssues": ["Vibration excessive", "Surchauffe"]
}
```

#### Collection: `sessions`
```json
{
  "id": "SES001",
  "operatorMatricule": "OP001",
  "technicianMatricule": "TECH001",
  "machineReference": "REF-2024-001",
  "issueTitle": "Problème de vibration",
  "issueDescription": "Vibration anormale détectée",
  "keywords": ["vibration", "moteur", "maintenance"],
  "startTime": "2024-01-15T10:00:00Z",
  "endTime": "2024-01-15T11:30:00Z",
  "status": "resolved",
  "interventionType": "remote",
  "resolutionNotes": "Réglage des paramètres de vitesse",
  "chatMessages": [
    {
      "sender": "OP001",
      "message": "J'ai une vibration anormale",
      "timestamp": "2024-01-15T10:00:00Z"
    }
  ]
}
```

#### Collection: `work_tracking`
```json
{
  "matricule": "OP001",
  "type": "operator",
  "startTime": "2024-01-15T08:00:00Z",
  "endTime": "2024-01-15T17:00:00Z",
  "status": "completed",
  "machinesWorkedOn": ["MCH001", "MCH002"]
}
```

## Étape 4: Configuration Firebase dans le Code

### 1. Initialisation Firebase
```dart
// Dans main.dart
import 'package:firebase_core/firebase_core.dart';
import 'services/firebase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MainApp());
}
```

### 2. Règles Firestore
Dans Firebase Console > Firestore > Règles:
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if true; // Pour le développement
    }
  }
}
```

## Étape 5: Test de Connexion

###
