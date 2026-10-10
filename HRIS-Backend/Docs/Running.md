# HRIS — Cara Menjalankan

Panduan menjalankan aplikasi.

---

## 0. Status: SUDAH BISA DIJALANKAN (setup lokal)

Repo ini telah dikonfigurasi agar bisa jalan secara lokal **tanpa** repo Git config asli:

- `ConfigServerGit` diubah ke profil **native** (config lokal di `ConfigServerGit/src/main/resources/config/`).
- Dibuat file konfigurasi per service (port, DB, RabbitMQ, Elasticsearch, Redis, JWT, route gateway).
- Dibuat `docker-compose.yml` untuk infrastruktur (PostgreSQL, MongoDB, Redis, RabbitMQ, Elasticsearch, MailHog).
- Dibuat script `run-local.sh` untuk build/start/stop.

Cara tercepat:

```bash
export JAVA_HOME="$HOME/.local/opt/jdk-17.0.20.1+1"   # JDK 17 portable
./run-local.sh build      # build semua modul (sekali saja)
./run-local.sh start      # nyalakan infra + config + semua service + gateway
./run-local.sh status
./run-local.sh logs auth  # lihat log service tertentu
./run-local.sh down       # matikan semua
```

Verifikasi cepat (contoh):

```bash
curl -X POST http://localhost:8080/api/v1/auth/save \
  -H 'Content-Type: application/json' \
  -d '{"name":"Budi","surname":"Santoso","email":"budi@example.com","password":"rahasia123","userRole":"ADMIN"}'

curl -X POST http://localhost:8080/api/v1/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"budi@example.com","password":"rahasia123"}'
```

Pemetaan port hasil setup:

| Service | Port |
|---|---|
| ApiGateway | 8080 |
| Config Server | 8888 |
| Auth | 9090 |
| Admin | 9091 |
| Company | 9092 |
| CompanyAdmin | 9093 |
| Personal | 9094 |
| Request | 9095 |
| Mail | 9096 |
| Elastic | 9100 |
| PostgreSQL / Mongo / Redis / RabbitMQ / Elasticsearch / MailHog SMTP | 5432 / 27017 / 6379 / 5672 / 9200 / 1025 |

> Beberapa port (`Request` 9095, `Mail` 9096, `Gateway` 8080) **ditentukan saat setup lokal** karena
> nilai aslinya tidak ada di kode.

---

## 1. Ringkas: kenapa awalnya belum bisa langsung `run`

Aplikasi ini **tidak bisa dijalankan apa adanya** karena tiga hal:

1. **Config Server menunjuk repo Git yang sudah tidak tersedia.**
   `ConfigServerGit/src/main/resources/application.yml:14` menarik konfigurasi dari
   `https://github.com/ErenDuzel/humanResourcesInformationSystemConfigServer.git`
   dan membutuhkan env `gitUsername` + `GIT_JAVA6_KEY`. Repo tersebut **404 / privat**.
   Semua service lain mengambil konfigurasi dari Config Server ini, sehingga bila gagal,
   seluruh service gagal start.

2. **Versi Java tidak kompatibel.**
   Project menargetkan **Java 17** (`build.gradle:17`) dan memakai **Gradle wrapper 7.4**
   (`gradle/wrapper/gradle-wrapper.properties`). Gradle 7.4 tidak mendukung Java 18+.
   Mesin ini memiliki **Java 27**, sehingga `./gradlew` akan error.

3. **Infrastruktur tidak disediakan.**
   Tidak ada `docker-compose`. Dibutuhkan PostgreSQL, MongoDB, Redis, RabbitMQ,
   Elasticsearch, dan (opsional) Zipkin.

Selain itu, `AdminMicroService` dan `ApiGatewayService` belum punya jar di `build/libs`
(modul lain sudah ada).

## 2. Prasyarat

| Kebutuhan | Keterangan |
|---|---|
| JDK 17 | Wajib. Gunakan Temurin/Corretto 17. |
| Gradle | Pakai `./gradlew` (wrapper 7.4), cukup dengan JDK 17. |
| PostgreSQL | Untuk Auth, Admin, CompanyAdmin, Personal, Request. |
| MongoDB | Untuk Company. |
| Redis | Untuk Company, CompanyAdmin. |
| RabbitMQ | Untuk Admin, CompanyAdmin, Personal, Auth (produsen) dan Mail (konsumen). |
| Elasticsearch | Untuk Elastic. |
| SMTP | Untuk MailModelService. |
| Zipkin | Opsional (tracing). |

## 3. Urutan menjalankan (target)

```
1) ConfigServerGit          :8888
2) Infrastruktur            (Postgres, Mongo, Redis, RabbitMQ, Elasticsearch, Zipkin)
3) AuthMicroService         :9090
4) Admin :9091, Company :9092, CompanyAdmin :9093, Personal :9094
5) Elastic :9100, MailModelService
6) RequestMicroService
7) ApiGatewayService
```

Perintah Gradle per modul:

```bash
./gradlew :ConfigServerGit:bootRun
./gradlew :AuthMicroService:bootRun
./gradlew :AdminMicroService:bootRun
./gradlew :CompanyMicroService:bootRun
./gradlew :CompanyAdminMicroService:bootRun
./gradlew :PersonalMicroService:bootRun
./gradlew :ElasticMicroService:bootRun
./gradlew :MailModelService:bootRun
./gradlew :RequestMicroService:bootRun
./gradlew :ApiGatewayService:bootRun
```

## 4. Detail penghalang

### 4.1 Config Server
`ConfigServerGit/src/main/resources/application.yml`:

```yaml
server:
  port: 8888
spring:
  cloud:
    config:
      server:
        git:
          uri: "https://github.com/ErenDuzel/humanResourcesInformationSystemConfigServer.git"
          default_label: main
          username: ${gitUsername}
          password: ${GIT_JAVA6_KEY}
```

Env yang diminta: `gitUsername`, `GIT_JAVA6_KEY`, dan `ZIPKIN_URL`.

### 4.2 Environment
```
$ java -version   ->  openjdk 27
build.gradle      ->  JavaVersion.VERSION_17
gradle-wrapper    ->  gradle-7.4-bin.zip
```

### 4.3 Artefak build
| Modul | Jar tersedia? |
|---|---|
| Auth, Mail, ConfigServer, Company, CompanyAdmin, Personal, Request, Elastic | ya (`build/libs/*-v.0.1.jar`) |
| Admin | belum |
| ApiGateway | belum |

## 5. Rencana agar bisa dijalankan (tanpa repo config asli)

Karena repo konfigurasi asli hilang, solusi yang disarankan:

1. **Jadikan Config Server memakai konfigurasi lokal (native profile).**
   Ubah `ConfigServerGit` agar melayani file dari classpath/filesystem, bukan Git:

   ```yaml
   spring:
     profiles:
       active: native
     cloud:
       config:
         server:
           native:
             search-locations: classpath:/config
   ```

   Lalu letakkan file per service di `ConfigServerGit/src/main/resources/config/`:
   `auth-micro-service-application.yml`, `admin-micro-service-application.yml`,
   `company-micro-service-application.yml`, `company-admin-micro-service-application.yml`,
   `personal-micro-service-application.yml`, `request-micro-service-application.yml`,
   `elastic-service-application.yml`, `mail-micro-service-application.yml`,
   `api-gateway-config-application.yml`.

2. **Isi tiap file** dengan: `server.port`, datasource, JPA/Mongo/Redis/Elasticsearch,
   RabbitMQ, SMTP, JWT (`secretkey`/`issuer`/`audience`), dan (untuk gateway) route + fallback.

3. **Sediakan `docker-compose.yml`** untuk PostgreSQL, MongoDB, Redis, RabbitMQ,
   Elasticsearch, dan Zipkin. Gunakan port default agar cocok dengan `localhost` yang di-hardcode.

4. **Gunakan JDK 17** agar Gradle 7.4 dan target Java 17 berjalan mulus.

5. **Jalankan sesuai urutan di bagian 3.**

### Port yang harus dipenuhi (dari URL hardcoded)

| Service | Port |
|---|---|
| ConfigServer | 8888 |
| Auth | 9090 |
| Admin | 9091 |
| Company | 9092 |
| CompanyAdmin | 9093 |
| Personal | 9094 |
| Elastic | 9100 |

> Port `RequestMicroService`, `MailModelService`, dan `ApiGatewayService` tidak ditemukan di kode
> (berasal dari Config Server); tentukan sendiri asal konsisten dengan route gateway.

## 6. Catatan saat konfigurasi lokal

- Semua Feign memakai `http://localhost:<port>`; jangan ubah port service.
- `jwt.secretkey`/`issuer`/`audience` harus **sama** di semua service agar token valid lintas service.
- `MailSenderService` memakai literal `"${mailUsername}"` sebagai From — perlu perbaikan kode
  atau konfigurasi mail yang sesuai.
- Gateway route (predicate/filter/fallbackUri) harus didefinisikan di `api-gateway-config-application.yml`.
