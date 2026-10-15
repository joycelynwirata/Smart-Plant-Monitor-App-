# Smart Plant Monitor & Irrigation System

A smart plant monitoring and automated irrigation system that combines IoT sensors, an ESP32 microcontroller, a Flutter web application, Firebase, and AI-powered plant care assistance.

This project was developed as my Electrical Engineering Senior Design project at the University of Illinois Chicago.

## Overview

The system monitors plant and environmental conditions in real time and automatically controls irrigation based on soil moisture levels. Sensor data is transmitted from an ESP32 to Firebase and displayed through a Flutter web dashboard.

The application also integrates Google's Gemini AI to provide contextual plant-care recommendations based on sensor readings and user questions.

## Key Features

- Real-time soil moisture monitoring
- Ambient light monitoring using a BH1750 sensor
- Water reservoir level detection
- Automatic irrigation control
- Manual "Water Now" control
- Plant-specific watering profiles
- Historical soil moisture and light data visualization
- Firebase Authentication and cloud data storage
- Email alerts for dry soil, low water levels, and maintenance conditions
- AI-powered plant care assistant using Google Gemini

## AI / Machine Learning Integration

The application integrates the **Gemini 2.5 Flash** large language model through the Gemini API.

Gemini is used primarily for **inference** rather than model training or fine-tuning. Real-time plant information, including soil moisture and light conditions, can be incorporated into prompts to provide context-aware plant care recommendations.

Two AI-oriented features were developed:

### Plant Doctor

Provides AI-generated guidance for diagnosing plant-care issues and recommending possible actions.

### Sprout AI

An interactive chatbot that allows users to ask plant-care questions while incorporating current sensor information into the model context.

This demonstrates practical experience integrating a pre-trained AI model into an end-to-end IoT and web application.

## System Architecture

ESP32 + Sensors
        ↓
Firebase Realtime Database
        ↓
Flutter Web Application
        ↓
Authenticated Firebase Cloud Function
        ↓
Gemini API
        ↓
AI Plant Care Recommendations

Additional application and historical data are stored using Firebase Firestore.

## Hardware

- ESP32-S3
- BH1750 ambient light sensor
- Capacitive soil moisture sensor
- Water level sensor
- Relay module
- Water pump

## Software & Technologies

- Flutter / Dart
- C/C++
- ESP32
- Firebase Realtime Database
- Firebase Firestore
- Firebase Authentication
- Google Gemini API
- EmailJS
- fl_chart

## System Operation

The ESP32 continuously collects soil moisture, ambient light, and water-level measurements and uploads the readings to Firebase.

The irrigation controller uses a state-based control system with `IDLE`, `WATERING`, and `SOAKING` states. When soil moisture falls below the configured threshold, the pump operates in controlled watering cycles until the target moisture level is reached.

Users can monitor the system and manually activate watering through the Flutter dashboard.

## Project Highlights

- Developed a complete hardware-to-cloud IoT system
- Integrated real-time ESP32 sensor data with Firebase
- Designed an automated closed-loop irrigation controller
- Built an interactive Flutter web dashboard
- Implemented historical sensor-data visualization
- Integrated a pre-trained LLM for context-aware plant recommendations
- Implemented automated email notifications and manual remote control

## Development

Source is organized by responsibility: pages in `lib/`, shared care thresholds
in `lib/models/`, backend/device operations in `lib/services/`, and reusable UI
(chat, sensor history charts, metrics, and the water animation) in `lib/widgets/`.

```sh
flutter pub get
flutter analyze
flutter test
cd functions
npm ci
npm test
```

The functions runtime targets Node 24. The Firebase project configured in this
repository is `smart-plant-595ab`. Linux Firebase configuration is not provided.

## AI backend setup

The Flutter app calls the authenticated `getPlantAdvice` HTTP function. Both the
Plant Doctor and chat use this backend. No Gemini credential belongs in Flutter
source or build flags.

1. Revoke the Gemini keys previously embedded in the source, including any in Git
   history, using Google AI Studio / Google Cloud. Removing source text does not
   revoke a key. Firebase client configuration keys are separate and remain in
   the client configuration.
2. Create a replacement Gemini key and store it with Firebase Secret Manager:

   ```sh
   firebase functions:secrets:set GEMINI_API_KEY
   ```

3. Deploy the function and Firestore rules after reviewing the rules against any
   existing deployed rules:

   ```sh
   firebase deploy --only functions:getPlantAdvice,firestore:rules
   ```

   The rules allow each signed-in user to access only their own documents and
   deny client access to the backend quota counters. Admin SDK access bypasses
   these rules. The backend allows ten AI requests per user per minute and caps
   input size and output tokens. Keep signup abuse controls appropriate to your
   deployment; per-user quotas are not a project spending cap.

4. `GEMINI_MODEL` is a Firebase string parameter, defaulting to `gemini-2.5-flash`.
   Set it to a model available to your project when deploying. A different function
   deployment URL can be supplied with:

   ```sh
   flutter run --dart-define=PLANT_ADVICE_URL=https://YOUR_FUNCTION_URL
   ```

Backend configuration/deployment and key revocation require access to the cloud
account; local tests make no paid AI requests and send no emails.

The backend uses Firebase's [HTTP functions](https://firebase.google.com/docs/functions/http-events)
and Gemini's [generateContent API](https://ai.google.dev/api/generate-content).

## Sensor and alert behavior

The existing hardware protocol uses `liveData/plant1` with numeric
`soilMoisture` (centibars, higher means drier), `light` (lux), and `waterLevel`
(0 empty, 1 full). Numeric strings are accepted. Incomplete/invalid readings are
shown as unavailable and are not recorded as zeros. The `waterNow` flag follows
the existing firmware protocol: false, then true. Firmware must acknowledge or
reset that command; the app does not choose a pump run duration.

This is a single-device setup: the dashboard, AI, alerts, and history use the
first plant document in Firestore document-ID order. Additional plant profiles
are editable but do not represent separately paired hardware. History is now
stored under that plant's actual document ID. Existing history under the legacy
`plant1` document is left intact; no migration or deletion is performed.

History writes and alerts run from the sensor subscription, independently of the
visible dashboard. Alert conditions are also checked once per minute while the
home screen is active. Email uses the existing EmailJS service/template and
account configuration. Cooldowns are in memory and reset when the app restarts.
Background/reliable server-side alert delivery is not implemented. A deployed
Firebase project must also have appropriate Realtime Database ownership rules;
this repository does not define hardware pairing or device provisioning.

Web messaging is configured for this Firebase project. FCM tokens are saved per
signed-in user/device. Sending push notifications still requires a trusted
server sender and platform APNs/web push setup. macOS/Android release network
permissions are included; real hardware and cloud integration need device tests.
