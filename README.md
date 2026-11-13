# Current deployment preparation

See [the free deployment plan](docs/FREE_DEPLOYMENT.md) for Firebase Hosting plus
the free AI backend. The website is live at https://smart-plant-595ab.web.app;
AI Plant Doctor is deployed and a real authenticated response has passed.
Billing remains disabled and live security rules are unchanged.

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

The application integrates a configurable **Google Gemini** language model through the Gemini API.

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

The functions runtime targets Node 22. The Firebase project configured in this
repository is `smart-plant-595ab`. Linux Firebase configuration is not provided.

## AI backend setup

The Flutter app calls the authenticated Vercel endpoint at
`https://smart-plant-ai-phi.vercel.app/api/advice`. Plant Doctor and chat share
this backend. The Gemini key is stored only as a Sensitive Production Vercel
environment variable. No Gemini credential belongs in Flutter source or build flags.

The free deployment is live. See [deployment and redeployment details](docs/FREE_DEPLOYMENT.md).
Firebase Hosting uses the existing project; the AI backend runs on Vercel Hobby
with Node 22 and a free-tier Gemini key. No Blaze upgrade or rule deployment was
performed. Both email/password and anonymous Firebase Authentication remain enabled.

Registered users can use AI without separate enrollment. The Vercel endpoint
verifies Firebase tokens without Firebase service-account credentials or database
access. Its ten-request/minute limiter is per warm instance; Gemini free-tier
quotas are the global bound. The default model is `gemini-3.5-flash-lite` and
`GEMINI_MODEL` is an optional server environment override. Keep API billing disabled.
The legacy Firebase Function remains an undeployed alternative requiring Blaze;
do not run a general Firebase deploy or publish the draft rules.

Redeploy the website from the repository root:

```sh
flutter build web --release
firebase deploy --only hosting --project smart-plant-595ab
```

For backend changes, run `npx vercel deploy --prod --yes --scope joy-1479` from
`functions`. Revoke any previously exposed Gemini keys in their owning account;
removing them from source does not revoke them.

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
