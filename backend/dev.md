# Developer Notes: nurse-backend

## Overview
This backend provides RESTful APIs for nurse-side operations: nurse registration/login, patient management, visit recording, and document uploads. Built with Node.js, Express, MongoDB (Mongoose), JWT, and Multer for file uploads.

## Project Structure
- `index.js`: Main entry point. Sets up Express, CORS, connects to MongoDB, and mounts all routes.
- `package.json`: Lists dependencies (express, mongoose, dotenv, cors, jsonwebtoken, multer, firebase-admin, uuid, etc.).
- `.env`: Environment variables (DB connection, JWT secret, etc.).
- `src/config/`: DB and Firebase config.
- `src/controllers/`: Business logic for nurse, patient, and visit operations.
- `src/models/`: Mongoose schemas for Nurse, Patient, Visit.
- `src/routes/`: Express routers for nurse, patient, visit APIs.
- `src/middleware/`: Auth middleware (JWT), file upload middleware.
- `uploads/`: Stores uploaded files (if any).

## Key Files and Their Functionality

### Models
- **Nurse.js**: Nurse schema (name, email, password, role, department, status, etc.).
- **Patient.js**: Patient schema (demographics, contact, medical history, documents, visits, etc.).
- **Visit.js**: Visit schema (patientId, date, weight, height, BP, heartRate, temperature, etc.).

### Controllers
- **nurseController.js**: (If used) Handles nurse business logic.
- **patientController.js**: Register patient, add visit, generate patient IDs.
- **visitController.js**: Add new visit records.

### Middleware
- **authMiddleware.js**: JWT-based route protection.
- **uploadMiddleware.js**: Multer config for file uploads.

### Routes
- **nurseRoutes.js**: `/api/nurse` - Signup, login, update status.
- **patientRoutes.js**: `/api/patient` - Register, upload docs, list/get patients, add visits, upload profile/id, fetch photos/docs.
- **visitRoutes.js**: `/api/visit` - Add new visit.

## API Endpoints and Postman Testing

### Nurses
- `POST /api/nurse/signup` — Register nurse. Body: `{ name, email, password, role, department }`
- `POST /api/nurse/login` — Login nurse. Body: `{ email, password }`
- `PATCH /api/nurse/status/:id` — Update nurse status. Body: `{ status }` (JWT required)

### Patients
- `POST /api/patient/register` — Register patient. Body: `{ name, age, gender, contact, ... }`
- `POST /api/patient/upload/:patientId/documents` — Upload patient documents (form-data, files, patientId)
- `GET /api/patient/:patientId/documents` — List patient documents
- `GET /api/patient/:patientId/documents/:documentId` — Download a document
- `DELETE /api/patient/:patientId/documents/:documentId` — Delete a document
- `GET /api/patient/list` — List all patients
- `GET /api/patient/:id` — Get patient by ID
- `POST /api/patient/visit` — Add visit to patient. Body: `{ patientId, visit: {...} }`
- `GET /api/patient/:id/visits` — List all visits for a patient
- `POST /api/patient/upload/:patientId/profile` — Upload photo/id proof (form-data: photo, idProof)
- `GET /api/patient/:patientId/photo` — Get patient photo
- `GET /api/patient/:patientId/idproof` — Get patient ID proof

### Visits
- `POST /api/visit/add` — Add a new visit. Body: `{ patientId, date, weight, height, bp, heartRate, temperature }`

## How to Test with Postman
1. **Nurse Auth**: Register/login nurse, use token for protected endpoints.
2. **Patient Management**: Register, upload docs, fetch, list, upload profile/id, get photos, etc.
3. **Visits**: Add and fetch visit records.
4. **File Uploads**: Use form-data in Postman for endpoints accepting files.

---

## Notes
- All JWT-protected routes require the `Authorization: Bearer <token>` header.
- For file uploads, use Postman's form-data mode and select files as needed.
- Ensure MongoDB and backend are running before testing.
- Adjust CORS/frontend URL in `.env` if needed.

---

For any new developer, review the models first to understand the data flow, then check the controllers and routes for business logic and API structure. Use Postman collections for API testing and validation.
