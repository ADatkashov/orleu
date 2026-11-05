<!--
VERBATIM COPY of the owner's "ORLEU — MASTER ADDENDUM" and of the follow-up list of 7 further directions
(saved 2026-11-05 at the owner's request). Do not edit the text below. Status of every requirement: docs/ROADMAP.md.
-->

# ORLEU — MASTER ADDENDUM
## Missing Enterprise Features, Production Architecture & Business Operations

This addendum extends the main ORLEU implementation specification.

Do not replace existing requirements. Integrate these requirements into the architecture and implementation.

Continue working autonomously without intermediate approval.

## 1. ADVANCED BOOKING CAPABILITIES

Implement architecture and support for:

- Group bookings
- Multiple customers in one appointment
- Recurring appointments
- Appointment packages
- Service bundles
- Gift cards
- Memberships
- Class and event scheduling
- Waitlists
- Resource-based booking
- Equipment and room availability
- Multiple employees per appointment
- Multi-service appointments
- Booking deposits and cancellation fees
- No-show protection
- Booking capacity limits

Resource availability must be considered together with employee availability.

For example, a clinic appointment may require both a doctor and an available treatment room.

## 2. CUSTOMER EXPERIENCE

Add:

- Customer self-service portal
- Customer booking history
- Upcoming appointments
- Rescheduling and cancellation
- Saved favorite businesses
- Family and dependent profiles
- Multiple customer contact methods
- Customer communication preferences
- Consent history
- Customer data export and deletion workflows

Customers must be able to manage their appointments without contacting the business.

## 3. ADVANCED FINANCIAL OPERATIONS

Implement:

- Cash register operations
- Cash shifts
- Daily closing reports
- Cash and card payment separation
- Employee commissions
- Employee payouts
- Business expenses
- Revenue and expense categories
- Refund approval workflow
- Partial refunds
- Payment reconciliation
- Unpaid balances
- Financial export
- Invoice and receipt generation
- Tax configuration abstractions

Never calculate financial balances from UI state.

All financial operations must be recorded and auditable.

Do not claim to implement statutory fiscal receipts or tax compliance without verified local provider integrations and legal requirements.

## 4. ADVANCED SAAS BILLING

Implement:

- Subscription trials
- Trial expiration
- Grace periods
- Failed payment recovery
- Subscription renewal
- Plan upgrades
- Plan downgrades
- Proration where appropriate
- Subscription cancellation
- Usage metering
- Feature entitlements
- Billing history
- Invoice generation
- Subscription notifications
- Business plan comparison

Subscription enforcement must happen on the backend.

## 5. INTEGRATIONS

Create integration interfaces and implement only verified provider APIs.

Prepare integrations for:

- WhatsApp Business
- SMS providers
- Email providers
- Google Calendar
- Apple Calendar through supported mechanisms
- Payment providers
- Accounting exports
- Maps and address lookup
- Push notification providers

Create an integration registry.

Each integration must have:
- Configuration
- Credentials management
- Connection status
- Webhook handling
- Error logs
- Retry policies
- Health status

Never fabricate a successful external integration.

## 6. TRANSACTIONAL RELIABILITY

Implement:

- Transactional outbox pattern
- Idempotent command processing
- Reliable background jobs
- Retry with exponential backoff
- Dead-letter handling
- Webhook event deduplication
- Payment reconciliation
- Booking expiration jobs
- Notification retry handling
- Scheduled subscription processing

Ensure that a failed notification cannot roll back an already committed booking.

Ensure that payment retries cannot charge a customer twice.

## 7. MOBILE APPLICATION QUALITY

Implement:

- Deep links
- Universal links / Android App Links
- Push notifications
- Secure device registration
- Device session management
- Offline-friendly read access where appropriate
- Network recovery
- Request retry policies
- Upload retry handling
- App lifecycle handling
- Session expiration handling
- Accessible interface
- Dynamic text sizing
- Screen reader labels

Never claim a booking or payment was completed when the server has not confirmed it.

## 8. SECURITY HARDENING

Add:

- MFA
- Optional passkey-ready authentication architecture
- Session revocation
- Suspicious login detection
- Account lockout protection
- Login audit
- Privileged action audit
- Secure secret rotation
- File upload validation
- File access authorization
- Webhook replay protection
- Export authorization
- Data retention policies

Perform threat modeling for:
- Cross-tenant data access
- Booking manipulation
- Payment fraud
- Privilege escalation
- Account takeover
- Unauthorized data export

Create a documented security threat model.

## 9. BUSINESS GROWTH TOOLS

Implement:

- Referral programs
- Referral attribution
- Marketing campaigns
- Customer segmentation
- Customer reactivation
- Loyalty programs
- Gift cards
- Promotional landing pages
- SEO-friendly business pages
- QR booking links
- Booking widgets
- Shareable business profiles

Measure campaign performance using real attributable data.

## 10. BUSINESS INTELLIGENCE

Add:

- Revenue forecasting
- Booking demand trends
- Employee utilization
- Customer churn indicators
- Customer lifetime value
- Returning customer percentage
- Service profitability
- Branch comparisons
- Booking conversion funnel
- Marketing campaign performance

Clearly distinguish actual measurements from forecasts.

Forecasts must be labeled as estimates.

## 11. OPERATIONS AND DISASTER RECOVERY

Implement:

- Automated database backups
- Backup retention
- Backup restoration tests
- Recovery procedures
- Database migration rollback strategy
- Incident response documentation
- Dependency health monitoring
- Alerting
- Application performance monitoring
- Error tracking
- Capacity monitoring

Document RPO and RTO targets and verify that the actual infrastructure can meet them.

## 12. INFRASTRUCTURE CONSTRAINTS

Use:

- Neon PostgreSQL as the initial managed database.
- Cloudflare R2 for object storage.
- GitHub Actions with self-hosted runner compatibility.
- Docker and Kubernetes-ready deployment.
- Environment-specific configuration.

Do not introduce Redis by default. Add it only if a measurable workload or architectural requirement justifies it.

Do not use Codemagic.

Do not store secrets in GitHub repositories or application configuration files.

## 13. ARCHITECTURE QUALITY

Enforce:

- Clear domain boundaries
- Explicit module ownership
- Consistent API contracts
- Dependency inversion
- Database migration discipline
- Automated architecture checks where practical
- No circular module dependencies
- No uncontrolled shared database access
- No oversized service classes

Create architecture decision records for important decisions.

## 14. DELIVERY PRIORITIZATION

Do not attempt to implement every advanced feature simultaneously.

Deliver ORLEU in verified increments:

PHASE 1 — FOUNDATION
Authentication, multi-tenancy, business onboarding, branches, employees, services, scheduling, bookings.

PHASE 2 — COMMERCIAL CORE
CRM, deposits, payments, financial ledger, subscription plans, notifications.

PHASE 3 — OPERATIONS
Calendar, analytics, staff performance, public booking, administration, customer portal.

PHASE 4 — BUSINESS GROWTH
Marketing, loyalty, referrals, gift cards, packages, memberships.

PHASE 5 — ADVANCED PLATFORM
AI insights, forecasting, integrations, advanced automation, internationalization.

Finish and test each vertical workflow before moving forward.

Do not create empty modules and report them as implemented.

Maintain a clear implementation status and a list of production blockers.

## FINAL REQUIREMENT

ORLEU must be a commercially viable, maintainable, secure SaaS product.

The application must solve real business problems, not merely demonstrate a collection of screens.

Every implemented feature must have working business logic, backend validation, database persistence, authorization, and appropriate automated tests.

ORLEU — Your Business. Your Growth.

---

# FOLLOW-UP: 7 FURTHER DIRECTIONS BEFORE COMMERCIAL LAUNCH
(from the owner's message, same session)

| Направление             | Что добавить                                                                   |
| ----------------------- | ------------------------------------------------------------------------------ |
| 1. Legal & Compliance   | Пользовательские соглашения, Privacy Policy, согласия, правила хранения данных |
| 2. Localization         | Форматы дат, времени, телефонов, валют, адресов и часовых поясов               |
| 3. Data Import          | Перенос клиентов, услуг, сотрудников и записей из Excel/CSV                    |
| 4. Customer Acquisition | SEO, referral links, landing pages, регистрация бизнеса                        |
| 5. Platform Economics   | CAC, LTV, MRR, ARR, churn, subscription conversion                             |
| 6. Product Analytics    | Онбординг, воронка конверсии, feature adoption, retention                      |
| 7. Release Engineering  | App Store / Google Play, crash reporting, staged rollout, rollback             |

### Что особенно важно для Казахстана

* Корректная работа с персональными данными и требованиями локального законодательства.
* Поддержка KZT и международных валют.
* Реальные платежные интеграции.
* Локальные SMS и телефонные номера.
* Казахстанские форматы документов и адресов.
* Возможность экспорта финансовых данных для бухгалтерии.

### Рекомендованный порядок реализации (из сообщения владельца)

* Backend Foundation.
* Flutter Design System.
* Authentication & Multi-tenancy.
* Booking Engine.
* CRM & Business Management.
* Payments & Ledger.
* SaaS Subscriptions.
* Analytics & Admin.
* Testing & Security.
* Pilot Launch.

### Решения по инфраструктуре, зафиксированные владельцем

* Neon PostgreSQL.
* Cloudflare R2.
* Flutter + Spring Boot.
* GitHub Actions и self-hosted runner.
* Без Redis без реальной необходимости.
* Без Codemagic.

### Принцип владельца

Не расширять бесконечно scope: сначала построить работающий ORLEU. Требовать работающие сценарии от Flutter до Spring Boot и PostgreSQL, проверенные тестами. Перед публикацией и регистрацией компании отдельно решить вопрос существующих одноимённых проектов и товарных знаков в Казахстане.
