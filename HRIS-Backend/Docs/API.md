# HRIS — API Endpoint Catalog

Katalog endpoint REST hasil pembacaan `@RequestMapping` pada controller masing-masing service.
Path penuh = konstanta di `constants/EndPoints.java` + sub-path.

Base umum: `API = /api`, `VERSION = /v1`.

---

## AuthMicroService — base `/api/v1/auth`

`AuthController` (`@RequestMapping(AUTH)`).

| Method | Path | Handler | Fungsi |
|---|---|---|---|
| POST | `/api/v1/auth/save` | `save` | Registrasi user/kredensial baru |
| POST | `/api/v1/auth/deactivate/{id}` | `deactivate` | Set status NOT_ACTIVE |
| DELETE | `/api/v1/auth/delete/{id}` | `delete` | Hapus permanen |
| POST | `/api/v1/auth/update/password` | `updatePassword` | Ganti password |
| POST | `/api/v1/auth/update/mail` | `updateMail` | Ganti email |
| POST | `/api/v1/auth/login` | `login` | Autentikasi, balas JWT + role |
| POST | `/api/v1/auth/forgot?email=` | `forgot` | Reset password (generate + kirim queue + sinkron role service) |

## AdminMicroService — base `/api/v1/admin`

`AdminController` (`@RequestMapping(ADMIN)`).

| Method | Path | Fungsi |
|---|---|---|
| POST | `/api/v1/admin/save` | Buat admin |
| GET | `/api/v1/admin/getalldetail?id=` | Detail admin lengkap |
| GET | `/api/v1/admin/getminor?id=` | Info admin ringkas |
| PUT | `/api/v1/admin/update` | Update admin |
| PUT | `/api/v1/admin/editprofile` | Edit profil sendiri |
| DELETE | `/api/v1/admin/delete/{id}` | Hapus admin |
| POST | `/api/v1/admin/forgot` | Reset password (public) |

## CompanyMicroService — base `/api/v1/company`

`CompanyController` (`@RequestMapping(COMPANY)`).

| Method | Path | Fungsi |
|---|---|---|
| POST | `/api/v1/company/save` | Simpan company |
| PUT | `/api/v1/company/update` | Update company |
| DELETE | `/api/v1/company/delete?id=` | Hapus company |
| GET | `/api/v1/company/getbyid?id=` | Cari company |
| PUT | `/api/v1/company/deactivate?id=` | Nonaktifkan |
| GET | `/api/v1/company/getalldetails?id=` | Detail lengkap |
| GET | `/api/v1/company/getall` | Daftar semua |
| GET | `/api/v1/company/exist/{id}` | Cek keberadaan |
| PUT | `/api/v1/company/addpersonal?id=` | Tambah counter personel |
| PUT | `/api/v1/company/deletepersonal?id=` | Kurangi counter personel |

## CompanyAdminMicroService — base `/api/v1/companyadmin`

`CompanyAdminController` (`@RequestMapping(COMPANYADMIN)`).

| Method | Path | Fungsi |
|---|---|---|
| POST | `/api/v1/companyadmin/save` | Registrasi company admin |
| PUT | `/api/v1/companyadmin/update` | Update |
| DELETE | `/api/v1/companyadmin/delete?id=` | Hapus |
| GET | `/api/v1/companyadmin/getminordetails?id=` | Detail ringkas |
| GET | `/api/v1/companyadmin/getalldetails?id=` | Detail lengkap |
| GET | `/api/v1/companyadmin/getall` | Daftar semua |
| POST | `/api/v1/companyadmin/deactivate/{id}` | Nonaktifkan |
| DELETE | `/api/v1/companyadmin/harddelete?id=` | Hapus permanen |
| POST | `/api/v1/companyadmin/update/password` | Ganti password |
| POST | `/api/v1/companyadmin/forgot` | Reset password (public) |

## PersonalMicroService — base `/api/v1/personal`

`PersonalController` (`@RequestMapping(PERSONAL)`).

| Method | Path | Fungsi |
|---|---|---|
| GET | `/api/v1/personal/getminordetails?id=` | Detail ringkas |
| POST | `/api/v1/personal/save` | Buat personel |
| PUT | `/api/v1/personal/update` | Update |
| POST | `/api/v1/personal/deactivate/{id}` | Nonaktifkan |
| PUT | `/api/v1/personal/delete/{id}` | Soft delete |
| DELETE | `/api/v1/personal/delete/{id}` | Hard delete (path sama, verb beda) |
| GET | `/api/v1/personal/getallpersonal` | Daftar personel |
| POST | `/api/v1/personal/update/password` | Ganti password |
| GET | `/api/v1/personal/getalldetails?id=` | Detail lengkap |
| POST | `/api/v1/personal/forgot` | Reset password (public) |
| POST | `/api/v1/personal/personalinfo?id=` | Info ringkas personel (dipakai Request) |

## RequestMicroService

### base `/api/v1/advancepayment`
| Method | Path | Fungsi |
|---|---|---|
| POST | `/api/v1/advancepayment/save` | Ajukan advance payment |
| PUT | `/api/v1/advancepayment/update` | Update pengajuan |
| POST | `/api/v1/advancepayment/confirm` | Setujui |
| DELETE | `/api/v1/advancepayment/delete` | Hapus |
| POST | `/api/v1/advancepayment/decline` | Tolak |

### base `/api/v1/dayoff`
| Method | Path | Fungsi |
|---|---|---|
| POST | `/api/v1/dayoff/save` | Ajukan cuti |
| POST | `/api/v1/dayoff/delete` | Hapus |
| POST | `/api/v1/dayoff/update` | Update |
| POST | `/api/v1/dayoff/accept` | Setujui |
| POST | `/api/v1/dayoff/decline` | Tolak |

### base `/api/v1/expenditure`
| Method | Path | Fungsi |
|---|---|---|
| POST | `/api/v1/expenditure/save` | Ajukan pengeluaran |
| DELETE | `/api/v1/expenditure/delete` | Hapus |
| POST | `/api/v1/expenditure/update` | Update |
| POST | `/api/v1/expenditure/confirm` | Setujui |
| POST | `/api/v1/expenditure/decline` | Tolak |

## ElasticMicroService

### base `/api/v1/advancepayment`
| Method | Path | Fungsi |
|---|---|---|
| POST | `/api/v1/advancepayment/save` | Index dokumen |
| PUT | `/api/v1/advancepayment/update` | Update by `paymentRequestId` |
| DELETE | `/api/v1/advancepayment/delete?id=` | Hapus |
| GET | `/api/v1/advancepayment/getone?paymentRequestId=` | Ambil satu |
| GET | `/api/v1/advancepayment/getall?currentPage=` | Paged (COMPANYADMIN) |
| GET | `/api/v1/advancepayment/getall/{personalId}?currentPage=` | Paged per personel |

### base `/api/v1/dayoff`
| Method | Path | Fungsi |
|---|---|---|
| POST | `/api/v1/dayoff/save` | Index |
| GET | `/api/v1/dayoff/getone?dayOffRequestId=` | Ambil satu |
| GET | `/api/v1/dayoff/getall?currentPage=` | Paged (COMPANYADMIN) |
| GET | `/api/v1/dayoff/getall/{personalId}?currentPage=` | Paged per personel |
| POST | `/api/v1/dayoff/delete` | Hapus |
| POST | `/api/v1/dayoff/update` | Update |

### base `/api/v1/expenditure`
| Method | Path | Fungsi |
|---|---|---|
| POST | `/api/v1/expenditure/save` | Index |
| DELETE | `/api/v1/expenditure/delete` | Hapus |
| POST | `/api/v1/expenditure/update` | Update |
| GET | `/api/v1/expenditure/getone?expenditureRequestId=` | Ambil satu |
| GET | `/api/v1/expenditure/getall?currentPage=` | Paged (COMPANYADMIN) |
| GET | `/api/v1/expenditure/getall/{personalId}?currentPage=` | Paged per personel |

## ApiGatewayService — fallback

`FallbackController` (`@RequestMapping("/fallback")`). Semua GET.

| Path |
|---|
| `/fallback/authservice` |
| `/fallback/adminservice` |
| `/fallback/companyadminservice` |
| `/fallback/companyservice` |
| `/fallback/personalservice` |
| `/fallback/requestservice` |
| `/fallback/elasticservice` |

## ConfigServerGit

Endpoint standar Spring Cloud Config Server (disediakan framework):

- `GET /{application}/{profile}[/{label}]`
- `GET /{application}-{profile}.yml` (juga `.properties` / `.json`)
- `GET /{label}/{application}-{profile}.yml`

## Swagger / OpenAPI

Tiap service mengekspos `/v3/api-docs/**` dan `/swagger-ui/**` (permitAll). UI: `http://localhost:<port>/swagger-ui/index.html`.
