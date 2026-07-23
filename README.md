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
