# MacroTrack: Data-Driven Calorie & Macronutrient Tracker
MacroTrack is a high-fidelity mobile MVP designed to bridge the gap between dietary targets and daily execution. Developed as a cross-platform solution using Flutter and Firebase, this application provides users with real-time insights into their nutritional health through a clean, minimalist interface.

## 📱 Key Features
* Dynamic Dashboard: High-level summaries featuring a Teal circular progress ring for calorie targets and horizontal progress bars for macronutrient (Protein, Carbs, Fat) tracking.

* 7-Day Calorie Trend: Integrated line charts to monitor intake fluctuations over time, providing users with actionable historical data.

* 7-Day Macronutrient Distribution: Interactive pie chart providing users visibility on macronutrient intake proportion across meals in the last 7 days. Users can toggle between different macros.

* Real-Time Meal Logging: A categorized input system (Breakfast, Lunch, Dinner, Snacks) that fetches and updates data via Firebase Firestore in real-time.

* Private Nutrition Database: A CRUD-enabled library where users can define custom food items and set specific daily intake targets in kcal and grams.

* Multi-method Database Input: Besides manual data entry, users can efficiently register food items by scanning UPC barcode/QR code (currently limited to US-region products), or auto-fill data via AI-powered OCR.

## 🛠 Technical Stack
* Frontend: Flutter (Dart) for high-performance, cross-platform UI.

* Database: Firebase Firestore (NoSQL) for scalable, real-time data persistence.

* Authentication: Firebase Auth for secure user account management.

* Strorage: Firebase Storage utilizing internal `gs://` paths for storing uploaded images e.g. profile pictures.

* External API: FatSecret Platform API (REST) for US-region UPC barcode lookup and nutritional database synchronization.

* AI Integration: Firebase Extension (Multimodal Tasks with Gemini, model: Gemini 2.5 Flash) to automate the bridge between image uploads and structured data extraction.

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
Each user maintains a private, isolated library of custom food items.
* Path: `foods/{uid}/userFoods/{itemId}`
* Fields:
    * `name`: String (name of food)
    * `servingSize`: Number (quantity of food)
    * `servingUnit`: String (unit of measurement, in g, ml or pcs for now)
    * `kcal`: Number (food's energy content in kcal)
    * `protein`: Number (food's protein content in g)
    * `carbs`: Number (food's carbohydrates content in g)
    * `fat`: Number (food's fats content in g)

#### 3. `logs` Collection
A highly scalable sub-collection architecture containing food entries by users.
* Path: `logs/{uid}/dailyLogs/{date}/entries/{entryId}`
* Fields (`{entryId}`):
    * `foodName`: String (name of food)
    * `mealType`: String (which meal of the day - breakfast, lunch, dinner, or snacks)
    * `consumedQuantity`: Number (actual quantity inputted by user)
    * `unit`: String (unit of measurement, same as `servingUnit` in `foods` collection)
    * `kcal`: Number (calculated pro rata based on `consumedQuantity`)
    * `protein`: Number (calculated pro rata based on `consumedQuantity`)
    * `carbs`: Number (calculated pro rata based on `consumedQuantity`)
    * `fat`: Number (calculated pro rata based on `consumedQuantity`)
    * `timestamp`: Server timestamp for chronological sorting

_**Architecture Scalability:**_
* _Query Performance: By grouping entries under a specific `{date}` document, the app can calculate a day's total macros in a single sub-collection fetch._
* _CRUD Operations: Each food entry is an independent document, allowing users to edit or delete specific items (using the `entryId`) without affecting other food item entries for that day._
* _Data Integrity: Storing `consumedQuantity` alongside pro-rata macros ensures the app can re-calculate data immediately if the user edits this later._

## 🎨 Design Philosophy
The UI utilizes a high-contrast Orange (#ff6700) and Teal (#006666) color scheme on a pure white background to ensure maximum readability and a modern, professional aesthetic.

* Orange: Utilized for primary Calls-to-Action (CTAs) and interactive elements.

* Teal: Reserved for data visualization, progress completion, and success states.

## 🚀 Future Roadmap
* Pricing tiers: Introduce additional paid subscription tiers to access more advanced features.