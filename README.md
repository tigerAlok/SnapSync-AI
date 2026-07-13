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