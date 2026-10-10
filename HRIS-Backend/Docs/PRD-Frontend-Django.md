# PRD — Frontend HRIS (Django)

| | |
|---|---|
| **Produk** | Human Resources Information System (HRIS) — Frontend |
| **Versi dokumen** | 1.0 |
| **Target teknologi** | Python + Django |
| **Backend** | HRIS microservices (Spring Cloud), diakses via API Gateway `http://localhost:8080` |
| **Referensi backend** | `Docs/architecture.md`, `Docs/API.md`, `Docs/Security.md`, `Docs/DataModel.md` |
| **Status** | Draft untuk implementasi |

---

## 1. Latar Belakang

HRIS adalah sistem backend microservices untuk mengelola data HR: company, manager, karyawan (personal),
dan pengajuan (advance payment, day off, expenditure). Frontend belum tersedia. Dokumen ini mendefinisikan
kebutuhan produk untuk membangun **frontend berbasis Django** yang mengonsumsi API melalui **API Gateway**.

Saat ini backend **tidak memiliki frontend** dan **tidak memiliki service discovery**; semua akses harus lewat
gateway (`:8080`) yang meneruskan ke service sesuai prefix path. Autentikasi memakai **JWT** yang diterbitkan
`AuthMicroService` saat login.

## 2. Tujuan (Goals)

1. Menyediakan antarmuka login dan manajemen sesi untuk 3 peran: **ADMIN**, **COMPANYADMIN**, **PERSONAL**.
2. Memungkinkan **Site Admin** mengelola company dan menugaskan company manager.
3. Memungkinkan **Company Admin** mengelola karyawan dan menyetujui/menolak pengajuan.
4. Memungkinkan **Personnel** membuat, melihat, dan memantau status pengajuan.
5. Menyediakan pencarian & daftar pengajuan (memanfaatkan `ElasticMicroService`).

## 3. Non-Goals (di luar cakupan)

- Membuat/mengubah microservice backend (kecuali perbaikan bug yang disetujui).
- Fitur payroll, absensi real-time, atau notifikasi push.
- Mobile app native.
- Registrasi mandiri terbuka untuk admin (pembuatan akun dilakukan oleh peran berwenang / seed).

## 4. Persona & Hak Akses

| Peran (`ERole`) | Deskripsi | Kemampuan utama |
|---|---|---|
| `ADMIN` | Site Administrator | Kelola company, tugaskan/kelola company manager (CompanyAdmin) |
| `COMPANYADMIN` | Company Manager | Kelola karyawan (Personal) pada company-nya, approve/reject pengajuan |
| `PERSONAL` | Company Personnel | Buat & pantau pengajuan (advance payment, day off, expenditure) |

> Catatan: kontrol akses di backend sebagian besar berbasis **kepemilikan token**, tetapi banyak endpoint
> `permitAll`. Frontend **tetap wajib** menerapkan pembatasan menu berdasarkan `role` yang dikembalikan saat login.

## 5. Konteks Sistem

```
[Django Frontend]  --HTTP-->  [API Gateway :8080]  -->  Auth/Admin/Company/CompanyAdmin/Personal/Request
        |                                                                          |
        | JWT (Bearer) di setiap request                                           v
        |                                                            Elastic (pencarian pengajuan)
        v
  Session Django menyimpan token + role
```

- **Base URL API** (dev): `http://localhost:8080`
- **Auth**: `POST /api/v1/auth/login` → `{ id, token, role }`; token dikirim sebagai header `Authorization: Bearer <token>`.
- **Masa berlaku token**: **5 menit**, tanpa refresh token. Frontend harus menangani kedaluwarsa (redirect ke login / re-auth).
- **Format error**: JSON `{ code, message, fields }` (dari `GlobalExceptionHandler`).

## 6. Keputusan Arsitektur Frontend (Django)

Direkomendasikan **Django sebagai Backend-for-Frontend (BFF) dengan server-side rendering**:

- Django menyimpan **JWT di server-side session** (bukan di browser), sehingga token tidak terekspos ke JS/cookie publik.
- Django memanggil API Gateway via `requests`/`httpx` pada lapisan `services/`.
- Template Django (`Django Templates`) + **Bootstrap 5** untuk UI; opsional **HTMX/Alpine.js** untuk interaksi ringan.
- **Tanpa DRF** pada awalnya (karena tidak mengekspos API publik baru). DRF ditambahkan hanya bila akan ada klien lain.
- CSRF protection aktif untuk form; login memakai mekanisme yang sama.

Alternatif (tidak dipilih default): SPA (React/Vue) dengan DRF sebagai API proxy. Lebih berat, token harus dikelola di klien.

### 6.1 Struktur proyek yang disarankan

```
frontend/
├── config/                # settings, urls (project Django)
├── core/                  # base views, mixins, decorators role
├── accounts/              # login, logout, session JWT, forgot password
├── companies/             # (ADMIN) kelola company & manager
├── companyadmin/          # (COMPANYADMIN) kelola karyawan
├── personnel/             # (PERSONAL) profil & pengajuan
├── requests_app/          # pengajuan + approval + pencarian
├── api/                   # api_client.py, services per domain, exceptions
├── templates/
└── static/
```

## 7. Kebutuhan Fungsional

Ditulis sebagai **user story + kriteria penerimaan**. Endpoint backend dirujuk pada `Docs/API.md`.

### FR-01 Autentikasi

**US-01.1** Sebagai pengguna, saya dapat login dengan email & password.

- Form: `email`, `password`.
- Memanggil `POST /api/v1/auth/login`.
- Sukses: simpan `id`, `token`, `role` di session; redirect ke dashboard sesuai role.
- Gagal: tampilkan pesan dari `message` backend.
- **AC**: token & role tersimpan; menu sesuai role; token dikirim di semua request berikutnya.

**US-01.2** Sebagai pengguna, saya dapat logout.

- Hapus session; redirect ke login.

**US-01.3** Sebagai pengguna, saya dapat meminta reset password.

- Form email → `POST /api/v1/auth/forgot?email=...`.
- **AC**: pesan sukses/err tampil. (Email dikirim backend via queue → Mail service.)

**US-01.4** Penanganan token kedaluwarsa.

- Jika backend membalas **401/403** atau `message` menandakan `INVALID_TOKEN`, paksa logout + pesan "Sesi berakhir, silakan login lagi".

### FR-02 Dashboard

**US-02.1** Setiap peran melihat dashboard ringkas.

- `ADMIN`: jumlah company, aksi cepat buat company.
- `COMPANYADMIN`: daftar karyawan + pengajuan menunggu approval.
- `PERSONAL`: ringkasan pengajuan terakhir + tombol buat pengajuan.

### FR-03 (ADMIN) Manajemen Company

**US-03.1** Lihat daftar company — `GET /api/v1/company/getall`.
**US-03.2** Lihat detail company — `GET /api/v1/company/getalldetails?id=`.
**US-03.3** Buat company — `POST /api/v1/company/save`.
**US-03.4** Ubah company — `PUT /api/v1/company/update`.
**US-03.5** Hapus company — `DELETE /api/v1/company/delete?id=`.
**US-03.6** Aktif/nonaktifkan company — `PUT /api/v1/company/deactivate?id=`.

> Catatan: field form mengikuti entity `Company` (MongoDB). Kolom pasti perlu dicek terhadap `CompanySaveRequestDto`/`CompanyUpdateRequestDto`.

### FR-04 (ADMIN) Manajemen Company Admin / Manager

**US-04.1** Lihat daftar company admin — `GET /api/v1/companyadmin/getall`.
**US-04.2** Lihat detail — `GET /api/v1/companyadmin/getalldetails?id=` / `getminordetails?id=`.
**US-04.3** Daftarkan manager — `POST /api/v1/companyadmin/save` (backend juga membuat kredensial di Auth).
**US-04.4** Ubah data manager — `PUT /api/v1/companyadmin/update`.
**US-04.5** Nonaktifkan — `POST /api/v1/companyadmin/deactivate/{id}`.
**US-04.6** Hapus — `DELETE /api/v1/companyadmin/delete?id=` (soft) atau `DELETE /api/v1/companyadmin/harddelete?id=` (permanen).

### FR-05 (ADMIN / pengguna) Profil Admin

**US-05.1** Lihat/ubah profil — `GET /api/v1/admin/getalldetail?id=`, `GET /api/v1/admin/getminor?id=`, `PUT /api/v1/admin/editprofile`.
**US-05.2** Buat admin — `POST /api/v1/admin/save`.

### FR-06 (COMPANYADMIN) Manajemen Karyawan (Personal)

**US-06.1** Lihat daftar karyawan — `GET /api/v1/personal/getallpersonal`.
**US-06.2** Lihat detail — `GET /api/v1/personal/getalldetails?id=` / `getminordetails?id=`.
**US-06.3** Tambah karyawan — `POST /api/v1/personal/save`.
**US-06.4** Ubah karyawan — `PUT /api/v1/personal/update`.
**US-06.5** Nonaktifkan — `POST /api/v1/personal/deactivate/{id}`.
**US-06.6** Hapus — `PUT /api/v1/personal/delete/{id}` (soft) atau `DELETE /api/v1/personal/delete/{id}` (hard).
**US-06.7** Ganti password karyawan — `POST /api/v1/personal/update/password`.

### FR-07 (COMPANYADMIN) Approval Pengajuan

**US-07.1** Lihat pengajuan advance payment — `GET /api/v1/advancepayment/getall?currentPage=` (Elastic).
**US-07.2** Setujui / tolak — `POST /api/v1/advancepayment/confirm?id=` / `POST /api/v1/advancepayment/decline?id=`.
**US-07.3** Sama untuk day off — `GET /api/v1/dayoff/getall?currentPage=`, `POST /api/v1/dayoff/accept`, `POST /api/v1/dayoff/decline`.
**US-07.4** Sama untuk expenditure — `GET /api/v1/expenditure/getall?currentPage=`, `POST /api/v1/expenditure/confirm`, `POST /api/v1/expenditure/decline`.

**AC**: setelah aksi, daftar ter-refresh dan status berubah.

### FR-08 (PERSONAL) Pengajuan

**US-08.1** Buat advance payment — `POST /api/v1/advancepayment/save` (backend verifikasi gaji via Personal).
**US-08.2** Ubah — `PUT /api/v1/advancepayment/update`.
**US-08.3** Hapus — `DELETE /api/v1/advancepayment/delete?id=`.
**US-08.4** Buat day off — `POST /api/v1/dayoff/save`; ubah `POST /api/v1/dayoff/update`; hapus `POST /api/v1/dayoff/delete`.
**US-08.5** Buat expenditure — `POST /api/v1/expenditure/save`; ubah `POST /api/v1/expenditure/update`; hapus `DELETE /api/v1/expenditure/delete?id=`.
**US-08.6** Lihat pengajuan saya — `GET /api/v1/{advancepayment|dayoff|expenditure}/getall/{personalId}?currentPage=` (Elastic).
**US-08.7** Lihat detail — `GET /api/v1/{domain}/getone?...RequestId=` (Elastic).

### FR-09 (PERSONAL) Profil

**US-09.1** Lihat profil — `GET /api/v1/personal/getalldetails?id=`.
**US-09.2** Ganti password — `POST /api/v1/personal/update/password`.

## 8. Peta Halaman (Screen Map)

| # | Halaman | Rute Django (usulan) | Peran | Endpoint utama |
|---|---|---|---|---|
| 1 | Login | `/login/` | Publik | `POST /auth/login` |
| 2 | Lupa Password | `/password/forgot/` | Publik | `POST /auth/forgot` |
| 3 | Dashboard | `/` | Semua | — |
| 4 | Company — daftar | `/companies/` | ADMIN | `GET /company/getall` |
| 5 | Company — form | `/companies/new/`, `/companies/<id>/edit/` | ADMIN | `POST /company/save`, `PUT /company/update` |
| 6 | Company — detail | `/companies/<id>/` | ADMIN | `GET /company/getalldetails` |
| 7 | Company Admin — daftar | `/managers/` | ADMIN | `GET /companyadmin/getall` |
| 8 | Company Admin — form | `/managers/new/`, `/managers/<id>/edit/` | ADMIN | `POST /companyadmin/save`, `PUT /companyadmin/update` |
| 9 | Karyawan — daftar | `/employees/` | COMPANYADMIN | `GET /personal/getallpersonal` |
| 10 | Karyawan — form | `/employees/new/`, `/employees/<id>/edit/` | COMPANYADMIN | `POST /personal/save`, `PUT /personal/update` |
| 11 | Approval — advance | `/approvals/advance/` | COMPANYADMIN | `GET /advancepayment/getall`, `POST /.../confirm|decline` |
| 12 | Approval — day off | `/approvals/dayoff/` | COMPANYADMIN | `GET /dayoff/getall`, `POST /.../accept|decline` |
| 13 | Approval — expenditure | `/approvals/expenditure/` | COMPANYADMIN | `GET /expenditure/getall`, `POST /.../confirm|decline` |
| 14 | Pengajuan Saya (list) | `/my-requests/` | PERSONAL | `GET /{domain}/getall/{personalId}` |
| 15 | Buat pengajuan | `/my-requests/new/<type>/` | PERSONAL | `POST /{domain}/save` |
| 16 | Detail pengajuan | `/my-requests/<domain>/<id>/` | PERSONAL | `GET /{domain}/getone` |
| 17 | Profil | `/profile/` | Semua | `GET /{role}/getalldetails`, `editprofile`/`update` |

## 9. Pemetaan Model Backend → Form Frontend

| Domain | Entity | Field penting (untuk form) |
|---|---|---|
| Auth | `Auth` | `name`, `surname`, `email`, `password`, `userRole` |
| Company | `Company` | `name`, `status` (+ field lain pada DTO save/update) |
| CompanyAdmin | `CompanyAdmin`, `Address` | data pribadi + alamat (one-to-one) |
| Personal | `Personal`, `Address` | data pribadi + alamat + `salary` |
| AdvancePayment | `AdvancePayment` | `amount`, `currency`, `advancePaymentType`, `advanceDetails` |
| DayOff | `DayOff` | `type`, `startingDate`, `endDate`, `span` |
| Expenditure | `Expenditure` | `expenditureType`, `amount`, `currency`, `expendDetails` |

**Enum** (dipakai untuk dropdown):
- `ERole`: ADMIN, PERSONAL, COMPANYADMIN
- `EStatus`: ACTIVE, NOT_ACTIVE, DELETED (tergantung service)
- `Currency`, `EAdvancePaymentType`, `EDayOffType`, `ExpenditureType` (lihat `Docs/DataModel.md`)

> Verifikasi nama field final pada masing-masing `*RequestDto` sebelum implementasi form.

## 10. Kebutuhan Non-Fungsional

| Aspek | Ketentuan |
|---|---|
| Keamanan | Token hanya di server session; CSRF protection untuk form; validasi input di server & klien |
| Sesi | Tangani token expired 5 menit → auto logout + pesan |
| Error handling | Tampilkan `message` dari backend; mapping error code ke pesan ramah pengguna |
| Pagination | Gunakan `currentPage` pada endpoint Elastic (page size 5 untuk admin, 10 per-personal) |
| Responsif | Bootstrap 5, mobile-friendly |
| Observability | Logging request/response API (tanpa mencatat token/password) |
| Konfigurasi | `HRIS_API_BASE_URL` via environment (`.env`) |
| Waktu muat | Cold-start service bisa lambat (2–5 detik); tampilkan loading state; gateway punya fallback |

## 11. Batasan & Risiko Teknis (dari backend)

1. **Token 5 menit tanpa refresh** — UX harus disiapkan (mis. re-login cepat, peringatan).
2. **Banyak endpoint `permitAll`** — validasi otorisasi tidak boleh hanya mengandalkan backend; frontend harus membatasi per role.
3. **Tidak ada endpoint "list semua admin"** — halaman manajemen admin terbatas pada operasi by-id/save.
4. **Beberapa aksi `confirm/decline/accept` memakai query param `id`**, bukan body.
5. **Hapus soft vs hard** pada Personal/CompanyAdmin memakai verb/endpoint berbeda.
6. **Cold start** & **fallback gateway** dapat mengembalikan pesan "service unavailable" HTTP 200 — frontend harus mendeteksi body fallback, bukan hanya status code.
7. **Bug/PR kecil**: perbaikan `MailSenderService` sudah dilakukan agar `From` ter-resolve.

## 12. Kriteria Penerimaan Rilis (Milestone)

| Milestone | Isi | Kriteria |
|---|---|---|
| M1 — Auth | Login/logout, lupa password, guard role | Pengguna dapat login & diarahkan sesuai role |
| M2 — ADMIN | CRUD company, CRUD company admin/manager | Data tampil & tersimpan via gateway |
| M3 — COMPANYADMIN | CRUD karyawan, approval pengajuan | Approval mengubah status di Elastic |
| M4 — PERSONAL | Buat/ubah/hapus & lihat pengajuan | Pengajuan muncul di daftar & dapat dipantau |
| M5 — Polish | Pencarian, pagination, error/empty state, responsive | Semua halaman punya loading/empty/error state |

## 13. Rencana Pengujian

- **Unit**: klien API (mock gateway), formatters, decorator role.
- **Integrasi**: terhadap gateway lokal (`./run-local.sh start`), skenario per role.
- **E2E**: alur login → buat company → buat manager → buat karyawan → pengajuan → approval.
- **Negatif**: token expired, service fallback, input invalid.

## 14. Lampiran — Ringkasan Endpoint (lihat `Docs/API.md` untuk lengkap)

```
POST   /api/v1/auth/login
POST   /api/v1/auth/save
POST   /api/v1/auth/forgot?email=
GET    /api/v1/company/getall
POST   /api/v1/company/save
PUT    /api/v1/company/update
GET    /api/v1/companyadmin/getall
POST   /api/v1/companyadmin/save
GET    /api/v1/personal/getallpersonal
POST   /api/v1/personal/save
POST   /api/v1/advancepayment/save        PUT /api/v1/advancepayment/update
POST   /api/v1/advancepayment/confirm?id= POST /api/v1/advancepayment/decline?id=
GET    /api/v1/advancepayment/getall?currentPage=
GET    /api/v1/advancepayment/getall/{personalId}?currentPage=
POST   /api/v1/dayoff/save                POST /api/v1/dayoff/accept  POST /api/v1/dayoff/decline
POST   /api/v1/expenditure/save           POST /api/v1/expenditure/confirm  POST /api/v1/expenditure/decline
```

## 15. Pertanyaan Terbuka

1. Frontend memakai **server-rendered (BFF)** atau **SPA + DRF**? (default: BFF)
2. Perlukah registrasi mandiri, atau pembuatan akun hanya oleh peran berwenang? (default: tidak ada registrasi mandiri)
3. Perlu perpanjangan masa token (mis. 60 menit) di backend? (rekomendasi: ya, agar UX login lebih nyaman)
4. Nomor port/URL produksi gateway dan domain frontend?
