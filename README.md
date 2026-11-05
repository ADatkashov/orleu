# ORLEU — Your Business. Your Growth.

Multi-tenant B2B SaaS for appointment-based service businesses (working brand; trademark/domain availability is NOT verified).

**Status: early backend foundation. See [docs/IMPLEMENTATION_STATUS.md](docs/IMPLEMENTATION_STATUS.md) for exactly what works, what was tested and what is missing.** The Flutter apps, admin, and public booking web pages are not started.

## Run locally
```bash
# PostgreSQL 16 with a database/user "orleu"
export ORLEU_DB_PASSWORD=... ORLEU_JWT_SECRET=$(openssl rand -base64 48)
cd backend && ./gradlew bootRun        # API on :8080, Swagger UI at /swagger-ui.html
```
## Test
```bash
cd backend
./gradlew test                          # Testcontainers (needs Docker), or:
ORLEU_TEST_DB_URL=jdbc:postgresql://localhost:5432/orleu_test ORLEU_TEST_DB_USER=orleu ORLEU_TEST_DB_PASSWORD=orleu ./gradlew test
```
