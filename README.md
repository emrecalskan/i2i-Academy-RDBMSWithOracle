# i2i Academy - RDBMS with Oracle - Homework 3.1

Bu proje; Oracle Database XE, PL/SQL, Spring Boot, Flyway ve Docker kullanılarak geliştirilmiş basit bir kitap yönetim uygulamasıdır.

## Kullanılan Teknolojiler

- Java 17
- Spring Boot
- Oracle Database XE 21c
- PL/SQL
- Flyway
- HikariCP
- Docker Compose
- Maven

## Projenin Özellikleri

- Yazar, yayınevi ve kitap bilgilerini ilişkisel tablolarda saklar.
- Flyway ile veritabanı tablolarını otomatik oluşturur.
- Kitap eklendiğinde `AUDIT_LOGS` tablosuna otomatik kayıt oluşturur.
- Ham kitap verisini XML ve JSON formatına dönüştürür.
- XML ve JSON verilerini PL/SQL ile ayrıştırarak veritabanına ekler.
- Kitapları `SYS_REFCURSOR` kullanarak Java uygulamasına döndürür.
- Hatalı verilerde transaction işlemini geri alır.
- REST API üzerinden kitap ekleme ve listeleme işlemleri sunar.

## Ham Veri Formatı

Kitaplar aşağıdaki formatta gönderilir:

```text
kitapBaşlığı|yazarAdı|yayınevi;kitapBaşlığı|yazarAdı|yayınevi
```

Örnek:

```text
Dune|Frank Herbert|Chilton Books;The Hobbit|J.R.R. Tolkien|George Allen & Unwin
```

## Veritabanı Tabloları

- `AUTHORS`
- `PUBLISHERS`
- `BOOKS`
- `AUDIT_LOGS`

## PL/SQL Paketi

Veritabanı işlemleri `BOOK_OPERATIONS` paketi içinde bulunmaktadır.

Paket içerisindeki işlemler:

- `RAW_TO_XML`
- `RAW_TO_JSON`
- `IMPORT_BOOKS`
- `GET_ALL_BOOKS`

## Flyway Dosyaları

```text
src/main/resources/db/migration/
├── V1__create_book_schema.sql
├── V2__create_audit_trigger.sql
└── V3__create_book_operations_package.sql
```

## Projeyi Çalıştırma

### 1. Ortam dosyasını oluşturma

`.env.example` dosyasını `.env` adıyla kopyalayın:

```powershell
Copy-Item .env.example .env
```

Örnek `.env` içeriği:

```env
ORACLE_PASSWORD=OracleAdmin123
APP_DB_USERNAME=BOOK_APP
APP_DB_PASSWORD=BookApp_2026
```

### 2. Uygulamayı derleme

```powershell
.\mvnw.cmd package -DskipTests
```

### 3. Docker containerlarını başlatma

```powershell
docker compose up -d --build
```

Container durumlarını kontrol etmek için:

```powershell
docker compose ps
```

## DBeaver Bağlantı Bilgileri

```text
Host: localhost
Port: 1521
Service Name: XEPDB1
Username: BOOK_APP
Password: BookApp_2026
```

## API Endpointleri

### Kitap İçe Aktarma

```http
POST /api/books/import
Content-Type: text/plain
```

Örnek:

```powershell
curl.exe -X POST "http://localhost:8080/api/books/import" `
  -H "Content-Type: text/plain; charset=utf-8" `
  --data-binary "Dune|Frank Herbert|Chilton Books"
```

### Kitapları Listeleme

```http
GET /api/books
```

Örnek:

```powershell
curl.exe "http://localhost:8080/api/books"
```

## Containerları Durdurma

```powershell
docker compose down
```


**Emre Çalışkan**

i2i Academy RDBMS with Oracle ödevi kapsamında hazırlanmıştır.
