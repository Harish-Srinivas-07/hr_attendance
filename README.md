# HR Attendance App

A modern **Flutter-based attendance management system** tailored for HR workflows. This app ensures secure check-ins, real-time attendance tracking, and streamlined leave/approval processes — all wrapped in a clean UI with tamper detection safeguards (location spoof, root/emulator detection).

---

## 🚀 Features

### 🔐 Authentication
- Secure Login with validations
- Forgot Password flow with OTP reset

### 🧭 Bottom Navigation Bar
1. **Home**  
   → Summary of attendance, check-in history, and quick stats  
2. **Explore**  
   → Navigate attendance forms, request filters, and leave requests  
3. **Contacts**  
   → Company directory (for future collaboration)  
4. **Profile**  
   → Account info, leave balance, logout

### 🕘 Attendance Management
- Check-In / Check-Out with live location
- Location spoof detection
- Emulator & Root detection
- Auto-restrict access on tamper

### 📅 Dashboard (Home)
- Previous Check-in Logs
- Leave Balance & Details
- Pending/Approved Attendance Requests

### 📋 Leave Management
- Submit leave forms with reason & dates
- View leave status & history

### ✅ Admin Controls
- Approve/Reject leave & attendance requests
- Filter requests based on date/type/status

### 🔒 Security Checks
- Rooted device detection
- Emulator detection
- Location spoof detection (mocked GPS)
- Restricted access screen on detection

---

---

## 📷 Screenshots

> Below is a visual walkthrough of the app's key features.

---

### 🔐 Authentication

| Login | Forgot Password |
|:-----:|:---------------:|
| ![Login](https://github.com/user-attachments/assets/aebc3a7c-5b56-4ac2-af29-bd8a0da680ea) | ![Forgot Password](https://github.com/user-attachments/assets/cbbea03b-a84c-497c-ac6e-5a2971d54e4d) |

---

### 🧭 Navigation Tabs

| Home | Explore | Contacts | Profile |
|:----:|:-------:|:--------:|:-------:|
| ![Home](https://github.com/user-attachments/assets/9c2c2665-111d-452e-ba94-8b17c7984bba) | ![Explore](https://github.com/user-attachments/assets/f4e40f69-1901-4b5b-b600-e2858ed70d81) | ![Contacts](https://github.com/user-attachments/assets/7672b243-1c40-465d-bc7f-4e6c664f590e) | ![Profile](https://github.com/user-attachments/assets/65742e76-d9f4-4db8-999d-e8c4d79c66a9) |

---

### 🕘 Attendance

| Check-In | Check-Out |
|:--------:|:----------:|
| ![Check-In](https://github.com/user-attachments/assets/bb5315dd-152d-4463-8581-e71daa424389) | ![Check-Out](https://github.com/user-attachments/assets/e7a8383e-3c3d-47ca-aca5-a8a6d4e65435) |

| Break & Lunch Time | Sign Up |
|:------------------:|:--------:|
| ![Breaks](https://github.com/user-attachments/assets/183d74ae-ddf9-44c4-a116-199952830aa9) | ![Sign Up](https://github.com/user-attachments/assets/d8bc9afa-3167-45db-914a-a736e48836e5) |

---

### 📝 Requests & Approvals

| Leave Approvals | Filter Requests |
|:---------------:|:---------------:|
| ![Approvals](https://github.com/user-attachments/assets/d9c38915-c237-4527-a40e-f5c4d4be4237) | ![Filters](https://github.com/user-attachments/assets/22e20bf7-fdf0-4e0b-a7e7-2ee98eea4eef) |

---

### 🔚 Logout

| Logout |
|:------:|
| ![Logout](https://github.com/user-attachments/assets/6ec9f6a1-2782-4294-a67e-1b9e383267bf) |

---


## 🧑‍💻 Tech Stack

- **Flutter** (UI, state mgmt, animations)
- **Supabase** (Auth, Database, Storage)
- **Riverpod** (State management)
- **Custom Location Spoof Detection**

---

## ⚙️ Getting Started

1. **Clone Repo**

   ```bash
   git clone https://github.com/Harish-Srinivas-07/hr_attendance.git
   cd hr_attendance
   ```

2. **Install Dependencies**

   ```bash
   flutter pub get
   ```

3. **Run App**

   ```bash
   flutter run
   ```

---

## 🔐 Environment Variables

Create a `.env` file to store sensitive keys (Supabase URL, anon keys, etc.)

```
SUPABASE_URL=your_url_here
SUPABASE_ANON_KEY=your_key_here
```

---

## ✨ Highlights

* Tamper-proof app flow
* Modern UI with stateful routing
* Role-based access for Admin and Employees
* Secure data handling and request validation

---

## 🤝 Contribution

Pull requests are welcome. For major changes, please open an issue first.

---

## 📄 License

This project is **not open source**.

All source code, designs, and assets are © 2025 Harish Srinivas SR — **All rights reserved**.  
The repository is public **for demonstration and portfolio purposes only**. Unauthorized use is a violation of copyright law and may result in legal action.
Do not use, copy, or distribute without explicit permission.

📬 For inquiries: [sr.harishsrinivas@gmail.com] or via [GitHub Issues](https://github.com/Harish-Srinivas-07/hr_attendance/issues)

---

## 🙌 Author

**Harish Srinivas SR**
📎 [GitHub Profile »](https://github.com/Harish-Srinivas-07)

---

## 📌 Note
This app is designed for **real-world HR workflows**, including remote teams. It is **production-ready**, easily extensible, and built with security at its core.

1. Auth completed: Login, Register, Forget, Landing-Splash, Session management.
2. Leave form: Major Updates.
3. Approvals, bug fixes, final export.
