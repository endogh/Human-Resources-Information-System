# HRIS — Documentation Index

Dokumentasi ini disusun dari pembacaan kode sumber repository
`Human-Resources-Information-System` (Spring Boot + Spring Cloud microservices).

| Dokumen | Isi |
|---|---|
| [architecture.md](./architecture.md) | Gambaran umum, teknologi, katalog modul, peta port, Feign, datastore, messaging, konfigurasi |
| [Diagram.md](./Diagram.md) | Diagram ASCII: topologi, alur login, pembuatan admin, request, messaging, boot order |
| [Security.md](./Security.md) | JWT, filter, otorisasi per service, role/status, secrets, kelemahan |
| [API.md](./API.md) | Katalog endpoint REST tiap service |
| [DataModel.md](./DataModel.md) | Entitas/tabel/collection dan enum per service |
| [Running.md](./Running.md) | Cara menjalankan, prasyarat, penghalang, dan setup lokal |
| [PRD-Frontend-Django.md](./PRD-Frontend-Django.md) | PRD frontend Django: tujuan, user story, halaman, pemetaan endpoint |

## Temuan Utama

- Microservices tanpa service discovery; antar-service pakai **OpenFeign dengan URL `localhost` hardcoded**.
- Semua konfigurasi runtime awalnya berasal dari **Config Server** yang menarik **repo Git eksternal yang sudah tidak tersedia**.
- Environment awal **Java 27**, sedangkan project butuh **Java 17** (Gradle wrapper 7.4).

**Sudah diatasi** dengan setup lokal: Config Server dipindah ke mode `native`, dibuat config per service,
`docker-compose.yml` untuk infrastruktur, dan script `run-local.sh`. Lihat
[Running.md](./Running.md) bagian 0 untuk cara menjalankan.

Status: build semua modul **berhasil** (JDK 17 portable) dan seluruh service + gateway **berjalan & terverifikasi**
(registrasi, login/JWT, routing gateway, enforcement token).
