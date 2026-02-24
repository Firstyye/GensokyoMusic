# 🎵 Touhou Music Streamer - App Specification

## 1. Project Overview
แอปพลิเคชัน Music Streaming เฉพาะกลุ่มสำหรับแฟนคลับแฟรนไชส์ **Touhou Project** โดยดึงข้อมูล Metadata ของเพลงจาก **TouhouDB API** และใช้แหล่งที่มาของเสียงจาก **YouTube** ผ่านกลไกการสกัด (Extraction) เพื่อสตรีมเสียงโดยตรง (Audio Streaming) พร้อมฟีเจอร์ Social สังคมออนไลน์ เช่น Live Parties และ Real-time Chat

## 2. Tech Stack & Dependencies
* **Framework:** Flutter (Dart)
* **Backend & Database:** Firebase (Authentication, Cloud Firestore สำหรับข้อมูลทั่วไป, Realtime Database/Firestore Snapshot สำหรับ Live Parties และ Chat)
* **Audio Pipeline:**
    * `just_audio`: สำหรับจัดการ State การเล่นเพลงและ UI Player
    * `youtube_explode_dart`: สำหรับรับ YouTube URL (ที่ได้จาก TouhouDB) มาสกัดเป็น Direct Audio Stream URL (.m4a/.webm) เพื่อป้อนให้ `just_audio`
* **Data Source:** TouhouDB REST API

## 3. Core Features (Functional Requirements)

### 3.1 Audio Streaming Pipeline (กลไกหลัก)
* เมื่อผู้ใช้กดเล่นเพลง ระบบจะรับ YouTube URL จาก TouhouDB
* ส่ง URL เข้า `youtube_explode_dart` เพื่อหา Audio-Only Stream ที่คุณภาพดีที่สุด
* นำ Direct Stream URL ที่ได้ โยนเข้า `just_audio` เพื่อเล่นเพลง
* *ข้อควรระวัง:* ห้ามเก็บ Direct Stream URL ลง Database เพราะลิงก์มีวันหมดอายุ ให้เก็บเฉพาะ YouTube Video ID/URL

### 3.2 Solo Listening Experience (โหมดฟังคนเดียว)
* **Mini Player:** แสดงผลอยู่ด้านล่างสุดของแอปตลอดเวลา (Persistent Overlay) แสดงข้อมูลเพลงปัจจุบัน, ปุ่ม Play/Pause, และแถบ Progress
* **Full-screen Player:** ขยายขึ้นมาเมื่อกดที่ Mini Player
* **Player Controls:** Play, Pause, Next, Previous, Seek (เลื่อนเวลา)
* **Playback Modes:** Shuffle (สุ่ม), Loop (เล่นซ้ำเพลงเดียว/ทั้งลิสต์)
* **Quick Actions:** ปุ่ม Favorite (กดหัวใจ) และ Add to Playlist

### 3.3 Favorites & Playlists (การจัดการคลังเพลงส่วนตัว)
* **Favorites:** บันทึกเพลงที่กดหัวใจไว้ใน Firestore ผูกกับ User ID
* **Custom Playlists:** ผู้ใช้สามารถสร้าง, แก้ไขชื่อ, และลบ Playlist ของตัวเองได้ พร้อมเพิ่มเพลงจาก TouhouDB เข้าไปเก็บไว้ได้ (CRUD operations)

### 3.4 Live Parties (โหมดฟังพร้อมกันแบบ Real-time)
* **Room Creation/Joining:** ผู้ใช้สามารถสร้างห้องฟังเพลงส่วนตัวหรือสาธารณะ และผู้อื่นสามารถกดเข้าร่วมได้
* **Synchronized Playback:** ทุกคนในห้องจะได้ยินเพลงเดียวกัน ณ เวลาเดียวกัน (Host เป็นผู้ควบคุม State การเล่นผ่าน Firebase)
* **Party Chat:** ระบบแชทสดภายในห้อง
* **Song Requests:** ผู้เข้าร่วมสามารถค้นหาเพลง (ผ่าน TouhouDB API) และกด Request เข้าไปในคิวของห้องได้

### 3.5 Social & 1-on-1 Chat (ระบบโซเชียล)
* **Add Friends:** ค้นหาเพื่อนด้วย User ID (Firebase UID หรือ Custom ID)
* **Real-time Private Chat:** ห้องแชทส่วนตัวระหว่างผู้ใช้ 2 คน
* **Music Sharing in Chat:** มีปุ่ม Search ภายในแชท เพื่อค้นหาเพลงจาก TouhouDB และกดส่งเป็น Message Card ให้เพื่อนกดฟังได้ทันที

### 3.6 User Profile & Settings
* จัดการข้อมูลผู้ใช้ (Display Name, Profile Picture)
* Authentication Management (Sign-out, Delete Account)

---

## 4. App Structure & Screens (โครงสร้างหน้า UI)
แอปพลิเคชันประกอบด้วยหน้าหลักอย่างน้อย 5 หน้า (Bottom Navigation Bar) ไม่รวมหน้า Auth

* **Screen 1: Home Screen (หน้าหลัก)**
    * แสดง Recommended Albums/Songs จาก TouhouDB
    * แสดงห้อง Live Parties ที่กำลัง Active ให้กดเข้าร่วมได้ทันที
* **Screen 2: Explore / Search (หน้าค้นหา)**
    * ค้นหาเพลง, ศิลปิน, หรืออัลบั้ม ผ่านระบบ Search ของ TouhouDB API
    * แสดง Top Rated Songs หรือ Trending
* **Screen 3: My Library (หน้าคลังเพลง)**
    * แสดงรายการ Favorites Songs
    * แสดงรายการ Playlists ที่ผู้ใช้สร้างไว้
* **Screen 4: Social / Messages (หน้าโซเชียล)**
    * แสดง List รายชื่อเพื่อน
    * แสดงประวัติห้องแชท (Chat History) สำหรับเข้าแชท 1-on-1
* **Screen 5: Profile & Settings (หน้าโปรไฟล์)**
    * แก้ไข Display Name, รูปโปรไฟล์ (Firebase Storage)
    * การตั้งค่าแอปพิลเคชันและปุ่ม Logout

*(Global UI Component)*: **Mini Player** จะถูกซ้อนทับ (Overlay) อยู่เหนือ Bottom Navigation Bar ในทุกๆ หน้า (ยกเว้นหน้า Auth และหน้าแชทบางหน้า)

---

## 5. Database Schema Structure (Firebase Recommendation)

*แนวทางการออกแบบ Firestore Collections เบื้องต้น:*
* `users/{uid}`: เก็บ displayName, photoUrl, friendsList (array of uid)
* `favorites/{uid}/songs/{songId}`: เก็บข้อมูล Metadata ของเพลงที่กดใจ
* `playlists/{playlistId}`: เก็บชื่อ Playlist, ownerUid, และ List ของเพลงในนั้น
* `chats/{chatId}`: เก็บข้อมูลห้องแชท 1-on-1
    * `messages/{messageId}`: เก็บข้อความ (text, timestamp, senderId, sharedSongData)
* `live_parties/{partyId}`: เก็บข้อมูลห้อง Live, hostUid, currentSongId, currentTimestamp, isPlaying
    * `chat/{messageId}`: ข้อความใน Live Party
    * `queue/{requestId}`: คิวเพลงที่มีคนขอเข้ามา