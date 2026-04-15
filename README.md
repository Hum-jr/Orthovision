# OrthoVision 🦴💻

![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)
![Hardware](https://img.shields.io/badge/hardware-ESP32%20%7C%20MPU6050-orange.svg)
![Software](https://img.shields.io/badge/software-Flutter%20%7C%20Godot-lightgrey.svg)

**OrthoVision** is a wearable sensor-based tele-rehabilitation system developed to digitize physical therapy and prevent musculoskeletal disorders. It provides real-time 3D posture tracking and correlates clinical pain (VAS scores) with objective angular deviations to serve as a Clinical Decision Support System.

## 📖 Project Overview

Currently, diagnosing and treating postural disorders largely rely on visual examinations in clinics and the patient's subjective statements. OrthoVision bridges the gap between subjective pain and objective physical deviation in a home environment. 

By placing ESP32 microcontrollers and 6-axis MPU6050 IMU sensors on critical joints, the system calculates instantaneous angular deviations (Pitch and Roll). This data is transmitted wirelessly to a Flutter-based mobile app and visualized in real-time on a 3D human skeleton using the Godot Engine. 

## ✨ Key Features

* **Real-Time 3D Posture Visualization:** Translates raw IMU data into a live 3D skeleton model using Inverse Kinematics (IK) in Godot.
* **Clinical Pain Correlation:** Integrates a Visual Analog Scale (VAS) input for patients to log pain levels.
* **AI/Algorithmic Decision Support:** Cross-analyzes subjective VAS scores with objective IMU angular data to identify specific postural deviations that trigger pain.
* **Wireless Sensor Nodes:** Utilizes ESP32 microcontrollers with Madgwick/Mahony filters for low-latency (<50ms) Wi-Fi/Bluetooth data streaming.
* **Tele-Rehabilitation Dashboard:** Allows physiotherapists to monitor patient progress and exercise accuracy remotely.

## 🏗️ System Architecture

### 1. Hardware Module
* **Microcontroller:** ESP32
* **Sensors:** MPU6050 (6-axis Accelerometer & Gyroscope)
* **Processing:** On-board sensor fusion (Madgwick filter) to prevent Gimbal Lock and stabilize Euler angles.

### 2. Software Module
* **Mobile Application:** Built with Flutter for cross-platform (Android/iOS) compatibility. Handles user authentication, VAS logging, and data charting.
* **3D Rendering Engine:** Built with Godot 3D. Receives quaternion/Euler data from the Flutter app to manipulate the bone nodes of a 3D humanoid rig.

## 🚀 Getting Started

### Prerequisites
* [Flutter SDK](https://flutter.dev/docs/get-started/install)
* [Godot Engine 3.x/4.x](https://godotengine.org/download)
* Arduino IDE or PlatformIO (for ESP32 flashing)

### Hardware Setup
1. Connect the MPU6050 to the ESP32 via I2C (`SDA`, `SCL`).
2. Flash the provided firmware located in the `/hardware/esp32_imu_node` directory.
3. Ensure the ESP32 and the mobile device running the app are on the same network (or paired via Bluetooth).

### Running the App
1. Clone the repository:
   ```bash
   git clone [https://github.com/yourusername/orthovision.git](https://github.com/yourusername/orthovision.git)
