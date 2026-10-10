# HRIS — Architecture

Human Resources Information System (HRIS) adalah aplikasi **backend berbasis microservices**
yang dibangun dengan **Spring Boot 2.7.9** dan **Spring Cloud 3.1.6**. Proyek ini merupakan
tugas akhir kuliah dan menggunakan arsitektur berlapis (layered architecture) per service.

> Dokumen ini disusun dari pembacaan kode sumber di repository ini. Nilai konfigurasi runtime
> (port, kredensial DB, route gateway) sebagian besar **tidak ada di repo** karena diambil dari
> Config Server eksternal. Lihat [Running.md](./Running.md).

---

## 1. Ringkasan

- **Pola**: microservices dengan Spring Cloud Config Server.
- **Service discovery**: TIDAK ADA Eureka/Ribbon/LoadBalancer. Antar-service memakai
  **OpenFeign dengan URL `http://localhost:<port>` yang di-hardcode**.
- **API Gateway**: `ApiGatewayService` (Spring Cloud Gateway) dengan CircuitBreaker Resilience4j.
- **Auth**: JWT (library `com.auth0:java-jwt`) + Spring Security di setiap service.
- **Komunikasi asinkron**: RabbitMQ (event password/email), hanya `MailModelService` yang menjadi consumer.
- **Build**: Gradle multi-module (`settings.gradle` mendaftarkan 9 modul; `ConfigServerGit` terdaftar dua kali).

## 2. Teknologi

| Kategori | Teknologi |
|---|---|
| Bahasa / Runtime | Java 17 (source/target), Spring Boot 2.7.9 |
| Cloud | Spring Cloud 3.1.6, Config Server (Git), Gateway, OpenFeign, Resilience4j |
| Database | PostgreSQL (JPA), MongoDB, Elasticsearch |
| Cache / Broker | Redis, RabbitMQ |
| Observability | Sleuth + Zipkin |
| Lain | JWT (auth0), MapStruct, Lombok, Springdoc OpenAPI (Swagger UI) |

## 3. Katalog Modul

| Modul | Application class | Anotasi penting | Build artifact |
|---|---|---|---|
| `ConfigServerGit` | `ConfigServerGitApplication` | `@EnableConfigServer` | `ConfigServerGit-v.0.1.jar` |
| `ApiGatewayService` | `ApiGatewayService` | `@SpringBootApplication` | belum ter-build |
| `AuthMicroService` | `AuthServiceApplication` | `@EnableFeignClients` | `AuthMicroService-v.0.1.jar` |
| `AdminMicroService` | `AdminServiceApplication` | `@EnableFeignClients` | belum ter-build |
| `CompanyMicroService` | `CompanyServiceApplication` | `@SpringBootApplication` | `CompanyMicroService-v.0.1.jar` |
| `CompanyAdminMicroService` | `CompanyAdminServiceApplication` | `@EnableFeignClients` | `CompanyAdminMicroService-v.0.1.jar` |
| `PersonalMicroService` | `PersonalMicroServiceApplication` | `@EnableFeignClients` | `PersonalMicroService-v.0.1.jar` |
| `RequestMicroService` | `RequestMicroServiceApplication` | `@EnableFeignClients` | `RequestMicroService-v.0.1.jar` |
| `ElasticMicroService` | `ElasticMicroServiceApplication` | `@EnableFeignClients` (tidak dipakai) | `ElasticMicroService-v.0.1.jar` |
| `MailModelService` | `MailServiceApplication` | `@SpringBootApplication` | `MailModelService-v.0.1.jar` |

Setiap service yang memiliki security memakai `@EnableWebSecurity` + `@EnableGlobalMethodSecurity(prePostEnabled = true)`.

## 4. Peran & Fitur (sesuai README)

| Peran (`ERole`) | Fitur |
|---|---|
| `ADMIN` (Site Administrator) | Menambah company ke database, menugaskan manager ke company |
| `COMPANYADMIN` (Company Manager) | Menambah employee, approve/reject request karyawan |
| `PERSONAL` (Company Personnel) | Membuat request: permission, advance payment, allowance |

`ERole` hanya berisi 3 nilai: `ADMIN, PERSONAL, COMPANYADMIN` (`AuthMicroService/.../entity/ERole.java`).

## 5. Peta Port

Sebagian port didefinisikan di Config Server (tidak ada di repo). Port berikut **tersirat dari URL Feign yang di-hardcode**.

| Service | Port | Sumber bukti |
|---|---|---|
| `ConfigServerGit` | **8888** | `ConfigServerGit/.../application.yml:2` |
| `AuthMicroService` | **9090** | Feign client di Admin/CompanyAdmin/Personal/Request |
| `AdminMicroService` | **9091** | `AuthMicroService/.../IAdminManager.java:11` |
| `CompanyMicroService` | **9092** | `AuthMicroService/.../ICompanyAdminManager.java`? — lihat Feign CompanyAdmin/Personal |
| `CompanyAdminMicroService` | **9093** | `AuthMicroService/.../ICompanyAdminManager.java:11` |
| `PersonalMicroService` | **9094** | `AuthMicroService/.../IPersonalManager.java:11` |
| `ElasticMicroService` | **9100** | `RequestMicroService/.../manager/IAdvancePaymentManager.java:11` |
| `RequestMicroService` | tidak diketahui | — |
| `MailModelService` | tidak diketahui | — |
| `ApiGatewayService` | tidak diketahui | — |

## 6. Komunikasi Antar-Service (OpenFeign)

Semua Feign memakai `url=` (hardcoded), sehingga atribut `name=` hanya sebagai bean id, bukan target discovery.

| Pemanggil | Feign interface | Target URL | Endpoint yang dipanggil |
|---|---|---|---|
| Auth | `IAdminManager` | `http://localhost:9091/api/v1/admin` | `POST /forgot` |
| Auth | `ICompanyAdminManager` | `http://localhost:9093/api/v1/companyadmin` | `POST /forgot` |
| Auth | `IPersonalManager` | `http://localhost:9094/api/v1/personal` | `POST /forgot` |
| Admin | `IAuthManager` | `http://localhost:9090/api/v1/auth` | `POST /save`, `DELETE /delete/{id}` |
| CompanyAdmin | `IAuthManager` | `http://localhost:9090/api/v1/auth` | `POST /save`, `POST /deactivate/{id}`, `DELETE /delete/{id}`, `POST /update/password`, `POST /update/mail` |
| CompanyAdmin | `ICompanyManager` | `http://localhost:9092/api/v1/company` | `GET /exist/{id}`, `PUT /addpersonal`, `PUT /deletepersonal` |
| Personal | `IAuthManager` | `http://localhost:9090/api/v1/auth` | sama seperti CompanyAdmin |
| Personal | `ICompanyManager` | `http://localhost:9092/api/v1/company` | `GET /exist/{id}`, `PUT /addpersonal`, `PUT /deletepersonal` |
| Request | `IPersonalManager` | `http://localhost:9094/api/v1/personal` | `POST /personalinfo` |
| Request | `IAdvancePaymentManager` | `http://localhost:9100/api/v1/advancepayment` | `POST /save`, `PUT /update`, `DELETE /delete` |
| Request | `IDayOffManager` | `http://localhost:9100/api/v1/dayoff` | `POST /save`, `POST /delete`, `POST /update` |
| Request | `IExpenditureManager` | `http://localhost:9100/api/v1/expenditure` | `POST /save`, `DELETE /delete`, `POST /update` |

`CompanyMicroService` tidak memakai Feign. `ElasticMicroService` punya `@EnableFeignClients` tetapi tidak ada client.

## 7. Penyimpanan Data

| Service | Datastore | Detail |
|---|---|---|
| `AuthMicroService` | PostgreSQL (JPA) | entity `Auth`, `BaseEntity`; tabel default |
| `AdminMicroService` | PostgreSQL (JPA) | `tbladmin`, `tbladdress` |
| `CompanyMicroService` | MongoDB + Redis | `@Document Company`; Redis cache (Lettuce, `${redis.host}`/`${redis.port}`) |
| `CompanyAdminMicroService` | PostgreSQL (JPA) + Redis | `tblCompanyAdmin`, `tbladdress`; Redis cache dipakai di service |
| `PersonalMicroService` | PostgreSQL (JPA) (+ Redis unused) | `tblpersonal`, `tbladdress` |
| `RequestMicroService` | PostgreSQL (JPA) | `tbladvance`, `tbldayoff`, `tblexpenditure` |
| `ElasticMicroService` | Elasticsearch | index: `advancepayment`, `dayoff`, `expenditure` |
| `MailModelService` | — | hanya kirim email |

## 8. Messaging (RabbitMQ)

Producer mendeklarasikan **direct exchange + queue + binding key**. `MailModelService` mengonsumsi queue dan mengirim email.

| Exchange | Binding key | Queue | Producer | Consumer (MailModelService) | Email |
|---|---|---|---|---|---|
| `admin-direct-exchange` | `admin-password-binding-key` | `admin-password-queue` | Admin | `AdminPasswordConsumer` | password admin |
| `company-admin-direct-exchange` | `company-admin-password-binding-key` | `company-admin-mail-queue` | CompanyAdmin | `CompanyAdminPasswordConsumer` | password company admin |
| `personal-direct-exchange` | `personal-password-binding-key` | `personal-password-queue` | Personal | `PersonalPasswordConsumer` | password personel |
| `auth-direct-exchange` | `reset-password-binding-key` | `reset-password-queue` | Auth | `ResetPasswordConsumer` | password reset |

## 9. Konfigurasi (Config Server)

Setiap service hanya memiliki `application.yml` berisi:

```yaml
spring:
  cloud:
    config:
      uri: http://localhost:8888
  config:
    import: "configserver:"
  application:
    name: <nama-aplikasi>
```

Nama aplikasi (kunci lookup konfigurasi):

| Service | `spring.application.name` |
|---|---|
| Auth | `auth-micro-service-application` |
| Admin | `admin-micro-service-application` |
| Company | `company-micro-service-application` |
| CompanyAdmin | `company-admin-micro-service-application` |
| Personal | `personal-micro-service-application` |
| Request | `request-micro-service-application` |
| Elastic | `elastic-service-application` |
| Mail | `mail-micro-service-application` |
| Gateway | `api-gateway-config-application` |

Config Server menarik konfigurasi dari repo Git eksternal (lihat [Running.md](./Running.md)) memakai
environment variable `gitUsername` dan `GIT_JAVA6_KEY`, serta `ZIPKIN_URL` untuk tracing.

## 10. Anomali & Catatan Teknis

- `settings.gradle` mendaftarkan `ConfigServerGit` **dua kali** (baris 5 dan 6).
- Terdapat direktori bersarang tak wajar `AuthMicroService/RequestMicroService/` (berisi folder `build`).
- `JwtUserDetails.loadUserByUsername()` mengembalikan `null` (hanya `loadUserByUserId` yang dipakai).
- `MailSenderService` awalnya memakai string literal `"${mailUsername}"`; sudah diperbaiki menjadi `@Value("${spring.mail.username}")`.
- `AdminMicroService` dan `ApiGatewayService` belum menghasilkan jar di `build/libs`.
- Dependency Redis dideklarasikan di `PersonalMicroService` tetapi tidak dipakai.
- Dependency RabbitMQ dideklarasikan di `RequestMicroService` tetapi tidak ada producer/consumer.
