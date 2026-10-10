# HRIS — Diagram

Semua diagram bersifat konseptual dan disusun dari kode sumber (bukan konfigurasi runtime).

---

## 1. Topologi Sistem

```
                             +-----------------------+
        Client (Web/App) --> |  ApiGatewayService    |  (Spring Cloud Gateway
                             |  :? (dari config)     |   + Resilience4j CB)
                             +-----------+-----------+
                                         | route (dari Config Server)
        +-------------+-------------+----+----+-------------+-------------+
        |             |             |         |             |             |
        v             v             v         v             v             v
   Auth :9090    Admin :9091   Company   CompanyAdmin  Personal     Request
                              :9092      :9093         :9094        :?
        |             |             |         |             |             |
        |             |             |         |             |             |
   +----+----+   +----+----+   +----+----+   +----+----+  +----+----+  +----+----+
   |Postgres |   |Postgres |   | MongoDB |   |Postgres |  |Postgres |  |Postgres |
   +---------+   +---------+   |  Redis  |   |  Redis  |  +---------+  +----+----+
                               +---------+   +---------+                   |
                                                                           | Feign
                                                                           v
                                                                     Elastic :9100
                                                                     (Elasticsearch)

   Semua Feign memakai http://localhost:<port>  (tanpa service discovery)

                             +-----------------------+
                             |    ConfigServerGit     |  :8888  --> Git repo eksternal
                             +-----------------------+
     ^ setiap service boot mengambil konfigurasi dari :8888 (spring.config.import=configserver:)
```

## 2. Ketergantungan Feign (siapa memanggil siapa)

```
                 +----------------+
                 | Auth :9090     |
                 +-------+--------+
        /save,/delete|         |  /forgot
     +---------------+         +----------------+----------------+
     |               |                          |                |
     v               v                          v                v
 Admin :9091   CompanyAdmin :9093         Admin :9091     CompanyAdmin/Personal
                                                (via /forgot)
        +----------------+          +----------------+
        | CompanyAdmin   |          | Personal       |
        | :9093          |          | :9094          |
        +---+--------+---+          +---+--------+---+
            |        |                  |        |
     /save,etc|   /exist,/addpersonal    |        |
            v        v                    |        |
        Auth :9090  Company :9092 <-------+--------+
                        ^
                        |
                  +-----+-----------+
                  | Request :?      |
                  +--+-----------+--+
             /personalinfo |    | /save /update /delete
                           v    v
                   Personal    Elastic :9100
                   :9094       (Elasticsearch)
```

## 3. Alur Login

```
Client -> Gateway -> Auth :9090  POST /api/v1/auth/login
                        |
                        |  AuthService.login (verify BCrypt password)
                        v
              JWT dibuat: claims { id, role, status }, HMAC512, expire 5 menit
                        |
                        v
                 { token, role } --> Client
```

Setelah login, client mengirim header `Authorization: Bearer <token>`.
Setiap service memverifikasi token dengan `JwtTokenFilter` -> `JwtUserDetails.loadUserByUserId(id)`.

## 4. Alur Pembuatan Admin (contoh aliran data + messaging)

```
Client -> Admin :9091  POST /api/v1/admin/save
              |
              |-- Feign --> Auth :9090  POST /api/v1/auth/save  (buat kredensial, balikkan id)
              |
              |-- simpan Admin ke PostgreSQL (tbladmin)
              |
              +-- publish ke exchange admin-direct-exchange
                        routing key: admin-password-binding-key
                                |
                                v
                       queue: admin-password-queue
                                |
                                v
                    MailModelService -> kirim email password (SMTP)
```

Pola yang sama berlaku untuk CompanyAdmin (`company-admin-mail-queue`) dan Personal (`personal-password-queue`).

## 5. Alur Lupa Password

```
Client -> Gateway -> Auth :9090  POST /api/v1/auth/forgot?email=...
              |
              |-- generate password baru, update DB
              |
              |-- publish ke auth-direct-exchange (reset-password-binding-key)
              |        -> queue reset-password-queue -> MailModelService (email)
              |
              +-- Feign ke service peran sesuai role:
                     ADMIN        -> Admin :9091        POST /forgot
                     COMPANYADMIN -> CompanyAdmin :9093 POST /forgot
                     PERSONAL     -> Personal :9094     POST /forgot
```

## 6. Alur Request Advance Payment (fan-out Feign + mirror ke Elasticsearch)

```
Client -> Gateway -> Request :?  POST /api/v1/advancepayment/save
              |
              |-- Feign --> Personal :9094  POST /api/v1/personal/personalinfo
              |             (ambil name, lastname, salary)
              |
              |-- simpan ke PostgreSQL (tbladvance) -> id request
              |
              +-- Feign --> Elastic :9100  POST /api/v1/advancepayment/save
                            (index dokumen agar bisa dicari)

Admin confirm/decline:
Client -> Request  POST /api/v1/advancepayment/confirm  (atau /decline)
              +-- Feign --> Elastic :9100  PUT /update  (sinkron status)
```

## 7. Circuit Breaker / Fallback (Gateway)

```
Client -> Gateway -> [service tidak tersedia]
                          |
                          v
              fallbackUri -> FallbackController  GET /fallback/<service>
                          |
                          v
              Response 200: "<service> Service is not available ..."
```

Endpoint fallback: `/fallback/authservice`, `/fallback/adminservice`, `/fallback/companyadminservice`,
`/fallback/companyservice`, `/fallback/personalservice`, `/fallback/requestservice`, `/fallback/elasticservice`.

## 8. Boot Order (runtime)

```
1) ConfigServerGit :8888      <-- harus paling awal
2) Infrastruktur: Postgres, MongoDB, Redis, RabbitMQ, Elasticsearch, Zipkin
3) Auth :9090
4) Admin :9091, Company :9092, CompanyAdmin :9093, Personal :9094
5) Elastic :9100, MailModelService
6) Request :? (butuh Personal + Elastic)
7) ApiGatewayService          <-- terakhir, sebagai pintu masuk
```

> Tanpa Config Server yang berisi konfigurasi, langkah 1 gagal sehingga seluruh service tidak bisa start.
