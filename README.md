# 📸 SnapSync AI

> AI-powered collaborative photo sharing platform with semantic search, face recognition, duplicate detection, automatic categorization, and original-quality image sharing.

---

## 🚀 Overview

SnapSync AI is a Flutter + FastAPI application that helps groups share photos in original quality while using AI to organize and search memories.

Instead of manually scrolling through hundreds of photos, users can:

- 🔍 Search photos using natural language
- 👤 Find photos of themselves using face recognition
- 🖼️ Detect similar photos
- 🗑️ Detect duplicate photos automatically
- ⭐ Keep the best quality duplicate
- 📂 Browse photos by AI-generated categories
- 🤖 Generate captions for uploaded photos

## 🛠️ Tech Stack

### Mobile
- Flutter
- Riverpod
- Firebase Authentication
- Cloud Firestore
- Cloudinary

### Backend
- FastAPI
- Python
- SQLite

### AI & Machine Learning
- OpenCLIP
- InsightFace
- Perceptual Hash (pHash)
- Pillow
- OpenCV

### Cloud Services
- Firebase
- Cloudinary

### Tools
- Git
- GitHub
- VS Code


## ✨ Features

### 📸 Photo Sharing
- Create and join private photo-sharing rooms
- Upload original-quality photos
- Secure cloud storage using Cloudinary
- Real-time synchronization with Firebase

### 🤖 AI Features
- 👤 Face Recognition (Find My Photos)
- 🔍 Semantic Photo Search using natural language
- 🖼️ Similar Photo Detection
- 🗂️ Automatic Photo Categorization
- 📝 AI Caption Generation
- 🗑️ Duplicate Photo Detection
- ⭐ Best Quality Photo Selection

### 🔒 Security
- Firebase Authentication
- Room-based access control
- Private AI indexing for authorized users only

### ⚡ Performance
- Optimized AI indexing
- Fast semantic search
- Automatic background photo processing


## 📸 Application Screenshots

### Authentication

| Login | Gallery |
|-------|---------|
| ![](screenshots/login_page.png) | ![](screenshots/gallery.png) |

---

### Room Management

| Rooms | Room Details |
|-------|--------------|
| ![](screenshots/rooms.png) | ![](screenshots/room_details.png) |

| Join Room |
|----------|
| ![](screenshots/room.png) |

---

### AI Features

| Face Search | AI Search |
|------------|-----------|
| ![](screenshots/face_search.png) | ![](screenshots/ai_search.png) |

| AI Photo Search | Categories |
|----------------|------------|
| ![](screenshots/ai_photo_search.png) | ![](screenshots/categories.png) |

| Duplicate Groups | Similar Photos |
|-----------------|----------------|
| ![](screenshots/duplicate_groups.png) | ![](screenshots/similar_photos.png) |

---

### Profile

| Profile |
|---------|
| ![](screenshots/profile_page.png) |


---

# 🏗️ System Architecture

```text
                +-----------------------+
                |   Flutter Mobile App  |
                +----------+------------+
                           |
                           |
          Firebase Authentication
                           |
                           v
                +-----------------------+
                |   Cloud Firestore     |
                | Rooms & Photo Metadata|
                +----------+------------+
                           |
                           |
                Upload / Search Requests
                           |
                           v
                +-----------------------+
                |   FastAPI Backend     |
                +----------+------------+
                           |
        +------------------+------------------+
        |                  |                  |
        v                  v                  v
   OpenCLIP          InsightFace        Image Analysis
 Semantic Search      Face Search      Duplicate Detection
                                         Categories
                                         Captions
                           |
                           |
                           v
                   Cloudinary Storage
```


---

# 📂 Project Structure

```text
SnapSync-AI
│
├── backend/
│   ├── app/
│   │   ├── services/
│   │   ├── database/
│   │   ├── main.py
│   │   └── ...
│   ├── requirements.txt
│   └── ...
│
├── mobile/
│   ├── lib/
│   │   ├── models/
│   │   ├── providers/
│   │   ├── repositories/
│   │   ├── screens/
│   │   ├── services/
│   │   └── main.dart
│   └── ...
│
├── screenshots/
├── docs/
└── README.md
```

---

# ⚙️ Installation & Setup

## 1. Clone the Repository

```bash
git clone https://github.com/tigerAlok/SnapSync-AI.git
cd SnapSync-AI
```

---

## 2. Backend Setup

```bash
cd backend

python -m venv venv

# Windows
venv\Scripts\activate

# macOS/Linux
source venv/bin/activate

pip install -r requirements.txt

uvicorn app.main:app --reload
```

Backend will start at:

```
http://127.0.0.1:8000
```

---

## 3. Flutter Setup

```bash
cd mobile

flutter pub get

flutter run
```

---

## 4. Configure Firebase

- Create a Firebase project
- Enable Firebase Authentication
- Create a Firestore Database
- Download `google-services.json`
- Place it inside:

```text
mobile/android/app/
```

---

## 5. Configure Cloudinary

Build the Flutter app with:

```bash
flutter run \
--dart-define=CLOUDINARY_CLOUD_NAME=<your-cloud-name> \
--dart-define=CLOUDINARY_UPLOAD_PRESET=<your-upload-preset>
```

For release:

```bash
flutter build apk --release \
--dart-define=CLOUDINARY_CLOUD_NAME=<your-cloud-name> \
--dart-define=CLOUDINARY_UPLOAD_PRESET=<your-upload-preset>
```

---

# 📡 Backend API Overview

| Endpoint | Description |
|----------|-------------|
| `POST /api/v1/photos/process` | AI processing after photo upload |
| `GET /api/v1/photos/search` | Semantic photo search |
| `POST /api/v1/face/reference` | Face search using a reference selfie |
| `GET /api/v1/photos/category` | Retrieve photos by AI-generated category |
| `GET /api/v1/photos/similar` | Find visually similar photos |
| `GET /api/v1/photos/duplicates` | Detect duplicate photos |
| `GET /api/v1/photos/duplicate-groups` | Automatically group duplicate photos |
| `DELETE /api/v1/photos` | Delete a photo and its AI indexes |

---

# 🚀 Future Improvements

- 🌐 Cloud deployment for the AI backend
- 📱 iOS application support
- 🎥 Video indexing and semantic search
- 👥 Shared albums with role-based permissions
- 🧠 Multilingual semantic search
- ☁️ Offline synchronization improvements
- 📊 AI-powered memory highlights
- 🔔 Smart photo recommendations

---

# 🎯 Key Learning Outcomes

This project demonstrates practical experience with:

- Flutter application architecture using Riverpod
- REST API development using FastAPI
- Firebase Authentication and Firestore
- Cloudinary image storage
- AI-powered semantic search with OpenCLIP
- Face recognition using InsightFace
- Image similarity and duplicate detection
- SQLite-based AI indexing
- Multi-device real-time synchronization
- End-to-end mobile application development


---

# 👨‍💻 Author

**Alok Raj (Tiger)**

- GitHub: https://github.com/tigerAlok
- LinkedIn: linkedin.com/in/alok-raj-tiger-041b28341

If you found this project interesting, consider giving it a ⭐ on GitHub.
