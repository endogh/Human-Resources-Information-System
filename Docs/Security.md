# HRIS — Security

Keamanan memakai **Spring Security + JWT stateless** (library `com.auth0:java-jwt` versi 4.3.0).
Setiap microservice (kecuali Config Server, Mail, dan Gateway) memiliki konfigurasi security-nya sendiri.

---

## 1. JWT

Dibuat hanya oleh `AuthMicroService` saat login (`JwtTokenManager.createToken`).

| Properti | Nilai / sumber |
|---|---|
| Algoritma | `HMAC512` |
| Secret | `${jwt.secretkey}` (dari Config Server) |
| Issuer | `${jwt.issuer}` |
| Audience | `${jwt.audience}` |
| Waktu kedaluwarsa | 5 menit (`1000 * 60 * 5`) |
| Claims | `id`, `role`, `status` (saat login); `id` saja pada varian token lain |

Referensi: `AuthMicroService/src/main/java/com/group/utility/JwtTokenManager.java:28-62`.

Semua service lain hanya **memverifikasi** token (bukan membuat) memakai `JWT.require(...).withIssuer(...).withAudience(...)`.

## 2. Alur Filter JWT

`JwtTokenFilter extends OncePerRequestFilter`, dipasang sebelum `UsernamePasswordAuthenticationFilter`.

```
Authorization: Bearer <token>
        |
        v
Ambil token (substring 7)
        |
        v
Verifikasi + ekstrak klaim
        |
        v
Muat UserDetails  ---> set SecurityContext.authentication
        |
        v
Lanjut filter chain
```

Ada **dua varian** pemuatan user:

| Varian | Service | Cara |
|---|---|---|
| Load by **user id** dari DB | Auth, Admin, CompanyAdmin, Personal, Request, Elastic | `jwtUserDetails.loadUserByUserId(id)` — query DB, authority = nama `ERole`, `accountLocked` bila status != ACTIVE |
| Load by **role claim** (tanpa DB) | Company | `jwtUserDetails.loadUserByRole(role)` — authority langsung dari klaim `role` token |

Perbedaan ini penting: `CompanyMicroService` memercayai klaim `role` di token, sedangkan service lain memvalidasi ulang ke database.

## 3. Otorisasi per Service

Semua config: `csrf().disable()` + `authorizeRequests()` + `anyRequest().authenticated()` +
`@EnableGlobalMethodSecurity(prePostEnabled = true)`.

| Service | Endpoint `permitAll` | File |
|---|---|---|
| `AuthMicroService` | `/v3/api-docs/**`, `/swagger-ui/**`, `/api/v1/auth/**` | `config/security/AuthServiceSecurityConfig.java:35-36` |
| `AdminMicroService` | `/v3/api-docs/**`, `/swagger-ui/**`, `/api/v1/admin/forgot` | `config/security/AdminServiceSecurityConfig.java:28-29` |
| `CompanyMicroService` | `/v3/api-docs/**`, `/swagger-ui/**`, `/api/v1/company/**` | `config/security/CompanyServiceSecurityConfig.java:22-23` |
| `CompanyAdminMicroService` | `/v3/api-docs/**`, `/swagger-ui/**`, `/api/v1/companyadmin/forgot` | `config/security/CompanyAdminServiceSecurityConfig.java:29-30` |
| `PersonalMicroService` | `/v3/api-docs/**`, `/swagger-ui/**`, `/api/v1/personal/**` | `config/security/PersonalServiceSecurityConfig.java:28-29` |
| `RequestMicroService` | `/v3/api-docs/**`, `/swagger-ui/**`, `/api/v1/advancepayment/**`, `/api/v1/dayoff/**`, `/api/v1/expenditure/**` | `config/security/RequestServiceSecurityConfig.java:28-30` |
| `ElasticMicroService` | `/v3/api-docs/**`, `/swagger-ui/**`, `/api/v1/advancepayment/**`, `/api/v1/dayoff/**`, `/api/v1/expenditure/**` | `config/security/ElasticServiceSecurityConfig.java:28-30` |

**Catatan**: karena endpoint utama banyak yang masuk daftar `permitAll`, proteksi efektif di
service-service tersebut sangat longgar. Role-based access (`@PreAuthorize`) hanya sebagian yang aktif
(beberapa dinyatakan aktif di Admin/Company, sebagian besar lainnya dikomentari di controller).

`ApiGatewayService` **tidak memiliki** konfigurasi security sendiri.

## 4. Penyimpanan Password

- `PasswordEncoder` = `BCryptPasswordEncoder` (bean di setiap config security).
- Hashing/pengecekan password dilakukan di service masing-masing (mis. `AuthService.login`).

## 5. Role & Status

| Enum | Nilai | Lokasi |
|---|---|---|
| `ERole` | `ADMIN`, `PERSONAL`, `COMPANYADMIN` | `AuthMicroService/.../entity/ERole.java` |
| `EStatus` (Auth) | `ACTIVE`, `NOT_ACTIVE` | `AuthMicroService/.../entity/EStatus.java` |
| `EStatus` (CompanyAdmin/Personal/Company) | `ACTIVE`, `NOT_ACTIVE`, `DELETED` | entity masing-masing |

`JwtUserDetails` (varian load-by-id) menandai akun terkunci ketika status bukan `ACTIVE`:

```java
boolean status = auth.get().getStatus().equals(EStatus.ACTIVE) ? false : true;
... .accountLocked(status)
```

## 6. Secrets & Konfigurasi Sensitif

Tidak ada secret yang tertanam di repo ini. Nilai berikut berasal dari Config Server eksternal:

- `jwt.secretkey`, `jwt.issuer`, `jwt.audience`
- kredensial datasource (PostgreSQL), MongoDB, Redis, RabbitMQ, Elasticsearch
- alamat SMTP untuk `MailModelService`
- `gitUsername`, `GIT_JAVA6_KEY` untuk Config Server, dan `ZIPKIN_URL`

## 7. Kelemahan / Hal yang Perlu Diperhatikan

- **Tidak ada refresh token / revocation.** Token berumur 5 menit dan tidak ada mekanisme logout server-side.
- **`CompanyMicroService` tidak memvalidasi role ke DB** — hanya membaca klaim token.
- **Gateway tanpa security** — autentikasi sepenuhnya bergantung pada service di belakangnya; karena banyak
  endpoint `permitAll`, sebagian request tidak benar-benar terproteksi.
- **`JwtUserDetails.loadUserByUsername()` mengembalikan `null`** (bukan implementasi standar).
- ~~`MailSenderService` memakai literal `"${mailUsername}"`~~ **sudah diperbaiki**: kini memakai `@Value("${spring.mail.username}")`.
- **`csrf().disable()`** wajar untuk API stateless, tetapi perlu dipastikan tidak ada konsumen berbasis cookie.
- Klaim `role`/`status` disimpan di token; jika secret bocor, token dapat dipalsukan (HS512 simetris, satu secret dipakai bersama semua service).
