# HRIS — Data Model

Ringkasan entitas/collection/dokumen per service, disusun dari kode entity.

---

## AuthMicroService (PostgreSQL / JPA)

| Entity | Tabel | Keterangan |
|---|---|---|
| `Auth` | (default JPA) | Kredensial: `id`, `name`, `email`, `password`, `role: ERole`, `status: EStatus` |
| `BaseEntity` | `@MappedSuperclass` | `createDate`, `updateDate` |

Enum: `ERole { ADMIN, PERSONAL, COMPANYADMIN }`, `EStatus { ACTIVE, NOT_ACTIVE }`.

## AdminMicroService (PostgreSQL / JPA)

| Entity | Tabel |
|---|---|
| `Admin` | `tbladmin` |
| `Address` | `tbladdress` (`@OneToOne` ke `Admin`) |
| `BaseEntity` | `@MappedSuperclass` |

## CompanyMicroService (MongoDB)

| Document | Index/Collection | Keterangan |
|---|---|---|
| `Company` | (default) | `@Id String id`, `name`, `status: EStatus`, dll. |
| `BaseEntity` | — | POJO biasa (bukan mapped) |

Enum: `EStatus { ACTIVE, NOT_ACTIVE }`. Redis dipakai sebagai cache (Lettuce).

## CompanyAdminMicroService (PostgreSQL / JPA)

| Entity | Tabel |
|---|---|
| `CompanyAdmin` | `tblCompanyAdmin` |
| `Address` | `tbladdress` (`@OneToOne` ke `CompanyAdmin`) |
| `BaseEntity` | `@MappedSuperclass` |

Enum: `EStatus { ACTIVE, NOT_ACTIVE, DELETED }`. Redis cache dipakai di service.

## PersonalMicroService (PostgreSQL / JPA)

| Entity | Tabel |
|---|---|
| `Personal` | `tblpersonal` |
| `Address` | `tbladdress` (`@OneToOne` ke `Personal`) |
| `BaseEntity` | `@MappedSuperclass` |

Enum: `EStatus { ACTIVE, NOT_ACTIVE, DELETED }`. (Redis di deps tetapi tidak dipakai.)

## RequestMicroService (PostgreSQL / JPA)

| Entity | Tabel | Field utama |
|---|---|---|
| `AdvancePayment` | `tbladvance` | `personalName`, `personalLastName`, `requestDate`, `confirmDate`, `currency`, `amount`, `advanceDetails`, `advancePaymentType`, `status`, `personalId` |
| `DayOff` | `tbldayoff` | `personalName`, `personalLastName`, `type`, `startingDate`, `requestDate`, `endDate`, `confirmDate`, `span`, `status`, `personalId` |
| `Expenditure` | `tblexpenditure` | `personalName`, `personalLastName`, `status`, `expenditureType`, `amount`, `requestDate`, `confirmDate`, `currency`, `expendDetails`, `personalId` |
| `BaseEntity` | `@MappedSuperclass` | `createDate`, `updateDate` |

Enum: `Currency`, `EAdvancePaymentType`, `EDayOffType`, `ExpenditureType`, `EStatus`.

## ElasticMicroService (Elasticsearch)

| Document | `indexName` | Ditambah |
|---|---|---|
| `AdvancePayment` | `advancepayment` | `paymentRequestId` (id dari Request service) |
| `DayOff` | `dayoff` | `dayOffRequestId` |
| `Expenditure` | `expenditure` | `expenditureRequestId` |
| `BaseEntity` | — | POJO: `createat`, `updateat`, `isactive` |

Enum: sama dengan RequestMicroService (`Currency`, `EAdvancePaymentType`, `EDayOffType`, `ExpenditureType`, `EStatus`).

Repository Elasticsearch menyediakan: `findByPaymentRequestId`/`findByDayOffRequestId`/`findByExpenditureRequestId` dan `findAllByPersonalId`.

## MailModelService

Tidak menyimpan data. Hanya memproses pesan RabbitMQ dan mengirim email.

Model pesan (semua `implements Serializable`, field `email` + `password`):
`AdminPasswordSenderModel`, `CompanyAdminPasswordModel`, `PersonalPasswordSenderModel`, `ResetPasswordModel`.

## Relasi Lintas Service

Tidak ada foreign key lintas database. Referensi antar service memakai **id numerik** yang dikirim lewat Feign,
mis. `Personal.personalId`, `AdvancePayment.paymentRequestId`, `Auth.id`.
