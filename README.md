# MacroTrack: Data-Driven Calorie & Macronutrient Tracker
MacroTrack is a high-fidelity mobile MVP designed to bridge the gap between dietary targets and daily execution. Developed as a cross-platform solution using Flutter and Firebase, this application provides users with real-time insights into their nutritional health through a clean, minimalist interface.

## 📱 Key Features
* Dynamic Dashboard: High-level summaries featuring a Teal circular progress ring for calorie targets and horizontal progress bars for macronutrient (Protein, Carbs, Fat) tracking.

* 7-Day Trend Analysis: Integrated line charts to monitor intake fluctuations over time, providing users with actionable historical data.

* Real-Time Meal Logging: A categorized input system (Breakfast, Lunch, Dinner, Snacks) that fetches and updates data via Firebase Firestore in real-time.

* Centralized Nutrition Database: A CRUD-enabled library where users can define custom food items and set specific daily intake targets in kcal and grams.

## 🛠 Technical Stack
* Frontend: Flutter (Dart) for high-performance, cross-platform UI.

* Backend: Firebase Firestore (NoSQL) for scalable, real-time data persistence.

* Authentication: Firebase Auth for secure user account management.

* Version Control: Git/GitHub managed via professional workflow (Staging, Commits, and Branching).

## 📊 Data Architecture (NoSQL)
Use Google Cloud Firestore for real-time data persistence. The database is designed with a hybrid of document-mapping and top-level collections to balance user privacy with a scalable global food library.

### Data Schema
#### 1. `users` Collection
Stores individual user profiles and daily target metrics.
* Document ID: Unique User ID (UID) from Firebase Auth.
* Fields:
    * `name`: String (registered name during sign-up)
    * `email`: String (registered email during sign-up)
    * `personalStats` (Map): User-defined biometric data. No function for now, may be used for calculations in future features.
        * `age`: Number
        * `height`: Number (in cm)
        * `weight`: Number (in kg)
    * `dailyTargets` (Map): User-defined daily intake thresholds for progress calculations.
        * `kcal`: Number (calorie intake in kcal)
        * `protein`: Number (protein intake in g)
        * `carbs`: Number (carbohydrates intake in g)
        * `fat`: Number (fats intake in g)

#### 2. `foods` Collection
A top-level collection containing standardized nutritional data entries for search and selection, i.e. the Food Library.
* Document ID: Auto-generated unique string.
* Fields:
    * `name`: String (name of food)
    * `kcal`: Number (food's energy content in kcal)
    * `protein`: Number (food's protein content in g)
    * `carbs`: Number (food's carbohydrates content in g)
    * `fat`: Number (food's fats content in g)

## 🎨 Design Philosophy
The UI utilizes a high-contrast Orange (#ff6700) and Teal (#006666) color scheme on a pure white background to ensure maximum readability and a modern, professional aesthetic.

* Orange: Utilized for primary Calls-to-Action (CTAs) and interactive elements.

* Teal: Reserved for data visualization, progress completion, and success states.

## 🚀 Future Roadmap
* AI Integration: Implementing image recognition to log meals via camera snapshots.

* Wearable Sync: Connecting with health APIs (Google Fit/Apple Health) for automated calorie expenditure tracking.

* Sustainability Focus: Adding "Carbon Footprint" tracking for food items, aligning with my professional focus on climate change and sustainability.