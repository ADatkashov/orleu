<!--
VERBATIM COPY of the owner's original "MASTER PROMPT FOR CLAUDE CODE" (saved 2026-11-05 at the owner's request).
Do not edit the text below; it is the owner's specification. Status of every requirement: docs/ROADMAP.md.
Note: the owner's message that contained this prompt also had some conversational text before it; only the prompt itself is kept here.
-->

# MASTER PROMPT FOR CLAUDE CODE
# ORLEU — Complete B2B SaaS Platform
## Your Business. Your Growth.

You are acting as an entire senior product and engineering organization:
- Principal Software Architect
- Senior Java / Spring Boot Engineer
- Senior Flutter Engineer
- Senior UI/UX and Product Designer
- Product Manager
- Database Architect
- DevOps / Cloud Engineer
- QA Automation Engineer
- Application Security Engineer

Your mission is to independently design, build, test, and document a new product from scratch: **ORLEU**, a premium international SaaS platform for service businesses.

Do not merely produce a proposal, architecture document, prototype, or list of recommendations. Implement the actual working application.

Work autonomously. Do not stop after creating a plan. Do not ask for approval between implementation stages. Make reasonable engineering decisions yourself, document them, and continue.

---

# 1. PRODUCT IDENTITY

**Product:** ORLEU
**Official slogan:** Your Business. Your Growth.
**Meaning:** Inspired by the Kazakh word Өрлеу — growth, progress, development, moving upward.

**Product category:** B2B SaaS — Business Management & Booking Platform.

**Product vision:**

ORLEU gives service businesses one integrated platform to manage their daily operations, customers, employees, bookings, payments, finances, and business growth.

The product must be suitable for:
- Beauty salons
- Barbershops
- Nail studios
- Spas and massage studios
- Medical and dental clinics
- Private practitioners
- Fitness and yoga studios
- Education and tutoring centers
- Auto services
- Repair and maintenance businesses
- Consulting services
- Other appointment-based businesses

Do not build an application exclusively for beauty salons. Build a flexible platform that supports different business verticals through configurable services, resources, booking rules, and business templates.

**Initial market:** Kazakhstan, starting with Almaty.

**Future markets:** Central Asia, Turkey, Europe, and international markets.

**Languages:**
- Kazakh (kk)
- Russian (ru)
- English (en)

All user-facing text must use proper localization. Do not hardcode UI strings.

**Default currency:** KZT.

**Default timezone:** Asia/Almaty.

Prepare the architecture for additional currencies, countries, languages, and timezones.

Important: use ORLEU as the working product brand, but do not claim that trademarks, domains, or app-store names are legally available. Keep branding configurable.

---

# 2. CORE PRODUCT ARCHITECTURE

Build a new, clean project.

Do not copy the old ZAIRO implementation or assume that its code is reusable. Do not delete or overwrite an existing repository or project. If the current workspace contains another project, create ORLEU in a separate directory or repository.

Recommended monorepo:

orleu/
  backend/
  mobile/
  admin/
  public-booking/
  infrastructure/
  docs/
  scripts/
  README.md

Use a modular monolith for the backend. Avoid premature microservices.

## Technology stack

### Backend
- Java 21 LTS
- Spring Boot 3.x, latest stable compatible version
- Spring Security
- Spring Data JPA
- Hibernate
- PostgreSQL
- Flyway database migrations
- Bean Validation
- Spring Actuator
- OpenAPI / Swagger
- Gradle Kotlin DSL
- JUnit 5
- Testcontainers

### Mobile
- Flutter, latest stable version
- Dart
- Riverpod for state management
- GoRouter for navigation
- Dio for HTTP
- Freezed / json_serializable where appropriate
- Secure storage for tokens
- Local persistence for appropriate offline functionality
- Flutter localization

### Admin
Build an administrative web interface using Flutter Web and shared design components where appropriate.

### Public booking
Build responsive public booking pages using Spring Boot server-rendered templates or an appropriately lightweight web implementation. Customers must be able to open booking links without installing the mobile application.

### Infrastructure
- PostgreSQL
- Neon PostgreSQL as the initial managed database option
- Cloudflare R2 for object storage
- Docker
- Docker Compose for local development
- Kubernetes-ready deployment manifests
- GitHub Actions
- Self-hosted runner compatibility

Do not introduce Redis unless there is a demonstrated technical requirement. Do not use Codemagic.

Use configuration through environment variables and deployment configuration, never hardcode secrets.

---

# 3. MULTI-TENANT SAAS FOUNDATION

This is one of the most important parts of ORLEU.

Multiple independent businesses must safely use the same platform.

Implement real multi-tenancy, not just a tenant_id field added superficially.

Each tenant must have:
- Business profile
- Business type
- Subscription
- Branches
- Employees
- Services
- Customers
- Booking settings
- Payment settings
- Business working hours
- Notifications
- Analytics
- Branding settings

Implement tenant isolation throughout:
- Database queries
- Repository methods
- Service methods
- API authorization
- File access
- Reports
- Background jobs
- Exports

Never trust tenant identifiers supplied by the client without validating authorization.

Use a consistent tenant resolution strategy.

Consider PostgreSQL row-level security where appropriate, but do not rely on it as the only security mechanism.

Add automated tests proving that one business cannot access another business's data.

---

# 4. USER ROLES AND ACCESS CONTROL

Implement role-based access control.

### Platform roles
- SUPER_ADMIN
- PLATFORM_SUPPORT
- PLATFORM_ANALYST

### Business roles
- BUSINESS_OWNER
- BUSINESS_ADMIN
- BRANCH_MANAGER
- STAFF
- ACCOUNTANT
- RECEPTIONIST

### Customer role
- CUSTOMER

A person may belong to multiple businesses and have different roles in each business.

Implement:
- Invitations
- Employee onboarding
- Role assignment
- Permission management
- Branch-level permissions
- Employee deactivation
- Session management
- Audit logging

Do not use a simplistic global role model for all business permissions.

---

# 5. AUTHENTICATION AND ACCOUNT SECURITY

Implement:

- Registration
- Login
- Phone number authentication
- Email authentication
- OTP verification
- Password login where enabled
- Password reset
- Refresh tokens
- Access token expiration
- Logout
- Logout from all devices
- Device/session tracking
- Account deletion request
- Account recovery
- Rate limiting
- Brute-force protection
- Secure token storage
- Optional MFA architecture

Use proper password hashing with Argon2id or another appropriate secure algorithm.

Access and refresh tokens must have separate lifecycles.

Never store passwords or sensitive tokens in plain text.

Implement authentication abstractions so SMS and email providers can be changed without rewriting the application.

For Kazakhstan, support phone numbers in international E.164 format, including +7.

---

# 6. BUSINESS ONBOARDING

Create a polished onboarding flow.

Step 1: Create an account.

Step 2: Business information:
- Business name
- Business type
- Logo
- Description
- Country
- City
- Address
- Phone
- Email
- Website
- Social links

Step 3: Create first branch.

Step 4: Configure working hours.

Step 5: Add first service.

Step 6: Add employees.

Step 7: Configure booking rules.

Step 8: Configure payment and deposit settings.

Step 9: Publish the booking page.

Step 10: Show the business dashboard.

Onboarding must be resumable. Save progress and allow users to continue later.

Provide ready-made templates for different business types.

---

# 7. BOOKING AND SCHEDULING ENGINE

This is the central product module.

Build a reliable scheduling engine.

## Service management

Each service must support:
- Name
- Description
- Category
- Duration
- Price
- Currency
- Image
- Preparation time
- Cleanup time
- Booking buffer
- Deposit requirement
- Cancellation policy
- Online availability
- Assigned employees
- Assigned branches
- Active/inactive status

Allow different prices and durations for different employees or branches when configured.

## Booking creation

A customer must be able to:

1. Open a business booking link.
2. Select a branch.
3. Select a service.
4. Select an employee or choose any available employee.
5. Select a date.
6. See available time slots.
7. Enter customer details.
8. Review price and deposit.
9. Pay a deposit when required.
10. Confirm the booking.

Support guest booking without mandatory application installation.

## Booking statuses

Implement a clear state machine:

- PENDING
- AWAITING_PAYMENT
- CONFIRMED
- CHECKED_IN
- IN_PROGRESS
- COMPLETED
- CANCELLED
- NO_SHOW
- EXPIRED

Validate every state transition on the backend.

Do not allow arbitrary status changes from the client.

## Scheduling requirements

Implement:
- Working hours
- Breaks
- Days off
- Holidays
- Employee shifts
- Employee leave
- Branch-specific schedules
- Service duration
- Buffers
- Resource availability
- Employee availability
- Booking conflicts
- Timezone-safe calculations
- Minimum booking notice
- Maximum advance booking window
- Cancellation deadlines
- Rescheduling rules
- Recurring appointments
- Waitlists

Use database transactions and appropriate locking or conflict-prevention techniques to prevent double booking.

Two customers must never successfully reserve the same unavailable employee/time slot.

## Calendar

Provide:
- Day view
- Week view
- Month view
- Employee calendar
- Branch calendar
- Service filters
- Booking status filters
- Drag-and-drop rescheduling where safe
- Calendar navigation
- Quick booking creation

The calendar should be one of the best-designed screens in ORLEU.

---

# 8. CUSTOMER RELATIONSHIP MANAGEMENT (CRM)

Build a complete customer management module.

Customer profile:
- Name
- Phone
- Email
- Birthday
- Notes
- Tags
- Visit history
- Total spending
- Last visit
- Upcoming bookings
- Cancellation history
- No-show count
- Loyalty information
- Communication preferences

Features:
- Customer search
- Filters
- Customer segmentation
- Customer import
- Customer export
- Duplicate detection
- Customer notes
- Customer history
- Customer blocking with audit trail
- Consent management
- Marketing opt-in

Add customer statistics:
- New customers
- Returning customers
- Retention
- Average spending
- Visit frequency
- Customer lifetime value

All CRM data must be tenant-isolated.

---

# 9. EMPLOYEE MANAGEMENT

Implement:
- Employee profiles
- Employee invitations
- Employee roles
- Branch assignment
- Services assigned
- Working schedules
- Vacation
- Sick leave
- Breaks
- Commission settings
- Performance statistics
- Personal calendars
- Employee availability
- Employee activity history

Employee performance:
- Number of bookings
- Completed appointments
- Cancelled appointments
- No-shows
- Revenue generated
- Average booking value
- Customer retention
- Ratings

Support permissions so employees only see information they are authorized to access.

---

# 10. BRANCH MANAGEMENT

Support multiple branches under one business.

Each branch has:
- Name
- Address
- Contact details
- Timezone
- Working hours
- Services
- Employees
- Booking settings
- Payment settings
- Public booking URL

Business owners should see consolidated statistics across branches.

Branch managers should only see their authorized branches.

---

# 11. FINANCE AND PAYMENTS

Build a reliable financial foundation.

Support:
- Service prices
- Deposits
- Remaining balances
- Partial payments
- Full payments
- Refunds
- Discounts
- Promo codes
- Manual payments
- Payment provider transactions
- Payment history
- Financial reports

## Deposit logic

A business can configure deposits from 0% to 100%.

For example:

Service price: 20,000 KZT
Deposit: 30% = 6,000 KZT
Remaining balance: 14,000 KZT

Show the following clearly:
- Total price
- Deposit amount
- Paid amount
- Remaining balance
- Payment status

All calculations must be performed and validated on the backend.

Use decimal-safe monetary calculations. Never use floating-point values for financial calculations.

## Financial ledger

Implement an immutable financial ledger.

Track:
- Customer payments
- Business revenue
- Deposits
- Remaining balances
- Refunds
- Discounts
- Platform subscription charges
- Platform fees
- Provider fees

Every financial operation must have:
- Unique identifier
- Amount
- Currency
- Type
- Status
- Timestamp
- Related booking or subscription
- Provider reference
- Audit information

Use idempotency keys for payment operations.

Never assume that a payment succeeded based only on a client callback.

Verify provider webhooks and payment status server-side.

Implement reconciliation mechanisms.

## Kazakhstan payment architecture

Create a provider abstraction.

Prepare integrations for:
- FreedomPay
- Kaspi payment workflows where supported
- Card payments through an authorized payment provider
- Manual cash payment
- Bank transfer

Do not invent provider APIs or assume recurring payment support.

Check official provider documentation and actual account capabilities before implementing real payment calls.

For unsupported integrations, build a clearly marked adapter interface and sandbox/mock implementation. Do not present mock payments as real payments.

## Subscription billing

ORLEU itself must support SaaS subscriptions.

Implement:
- FREE
- PRO

Prepare a flexible subscription engine for additional plans.

Support:
- Trial periods
- Subscription activation
- Renewal
- Expiration
- Upgrade
- Downgrade
- Cancellation
- Grace period
- Payment failure
- Invoice history
- Subscription entitlements

Do not promise automatic recurring billing unless the chosen provider actually supports it.

---

# 12. SAAS PRICING AND ENTITLEMENTS

Build a configurable plan management system.

Example initial structure:

FREE:
- One business
- One branch
- Limited employees
- Basic booking
- Basic CRM
- Basic analytics

PRO:
- Multiple branches
- More employees
- Advanced CRM
- Advanced analytics
- Automated reminders
- Advanced booking rules
- Marketing tools
- Advanced reporting
- Export capabilities

Do not hardcode plan limitations throughout the codebase.

Create a centralized entitlement service.

The backend must enforce all subscription limits.

The client must display current plan, usage, limits, and upgrade options.

Allow platform administrators to change plan configuration.

---

# 13. NOTIFICATION SYSTEM

Implement a centralized notification module.

Channels:
- Push notifications
- Email
- SMS
- In-app notifications

Booking events:
- Booking created
- Booking confirmed
- Booking cancelled
- Booking rescheduled
- Upcoming appointment
- Payment received
- Deposit required
- Payment failed
- Appointment completed
- No-show

Business events:
- New customer
- New booking
- Employee invitation
- Subscription renewal
- Subscription expiration
- Payment failure

Add configurable reminder schedules.

Prevent duplicate notifications.

Use asynchronous processing and retry policies.

Implement notification templates for kk, ru, and en.

Store notification delivery status.

---

# 14. MARKETING AND CUSTOMER RETENTION

Implement:
- Promo codes
- Discounts
- Loyalty points
- Customer segments
- Birthday campaigns
- Referral codes
- Referral tracking
- Customer reactivation campaigns
- Campaign statistics

Support consent and unsubscribe rules.

Marketing must never send messages to customers who have not provided the required consent.

---

# 15. BUSINESS ANALYTICS

Create an attractive analytics dashboard.

Metrics:
- Total revenue
- Revenue by branch
- Revenue by employee
- Revenue by service
- Number of bookings
- Completed bookings
- Cancellation rate
- No-show rate
- Average booking value
- New customers
- Returning customers
- Customer retention
- Employee utilization
- Popular services
- Peak booking hours

Filters:
- Today
- Yesterday
- Last 7 days
- Last 30 days
- This month
- Previous month
- Custom date range
- Branch
- Employee
- Service

Use accurate aggregation and timezone-aware date boundaries.

Distinguish gross revenue, collected payments, outstanding balances, refunds, and net revenue.

Do not mix booking value with actual collected cash.

Charts should be readable and responsive.

---

# 16. PUBLIC BUSINESS PROFILE AND BOOKING PAGE

Every business must receive a public booking page.

Example:

orleu.app/b/beauty-studio

The page should include:
- Business logo
- Cover image
- Business name
- Description
- Address
- Map link
- Contact details
- Branches
- Services
- Prices
- Employee profiles
- Available booking times
- Reviews
- Booking button

Support:
- Shareable links
- QR codes
- Social media links
- Custom booking page branding
- Booking widget integration
- Mobile-first responsive design

Do not require a customer to install ORLEU to book an appointment.

Implement secure booking links and prevent enumeration of private customer data.

---

# 17. RATINGS AND REVIEWS

Implement:
- Customer ratings
- Written reviews
- Review moderation
- Business responses
- Employee ratings
- Service ratings
- Verified booking indicator
- Review reporting

Only eligible customers with a valid completed booking should be able to leave a verified review.

Prevent duplicate reviews for the same booking.

---

# 18. PLATFORM ADMINISTRATION

Create a separate platform administration interface.

Platform administrator must manage:

- Businesses
- Users
- Subscriptions
- Plans
- Payments
- Branches
- Platform settings
- Feature flags
- Support requests
- Reviews
- Abuse reports
- Audit logs
- System health
- Usage metrics

Implement administrative permissions and detailed audit logging.

Never allow platform support users to silently impersonate customers or business owners.

If impersonation is implemented, make it explicitly authorized, time-limited, logged, and visible.

---

# 19. CUSTOMER SUPPORT

Build a support module:
- Support tickets
- Ticket categories
- Priorities
- Statuses
- Conversations
- Attachments
- Internal notes
- Assignment
- Resolution history

Business users should be able to contact ORLEU support.

Platform administrators should be able to manage tickets.

---

# 20. AI BUSINESS ASSISTANT — PREPARE FOR FUTURE

Design an AI integration module, but do not introduce fake AI features.

Potential capabilities:
- Business performance summaries
- Booking trend analysis
- Revenue insights
- Customer retention suggestions
- Schedule optimization
- Employee workload insights
- Natural language business reports
- Suggested marketing campaigns

Use provider abstraction for AI models.

Protect customer data and never send personally identifiable data to external AI providers without appropriate authorization and safeguards.

Implement AI capabilities only when there is a real, testable use case.

---

# 21. FLUTTER APP — COMPLETE DESIGN AND UX

Build a premium, production-quality Flutter application.

The design must look like a modern international SaaS product, not a generic admin template.

## Brand design system

Brand:
ORLEU

Slogan:
Your Business. Your Growth.

### Color palette

Use these design tokens:

Primary background: #F7F8F5
Surface: #FFFFFF
Primary dark: #14251D
Primary green: #176B52
Secondary green: #DDEDE3
Accent lime: #C7F36B
Text primary: #18231D
Text secondary: #758078
Border: #E7EBE6
Success: #25865B
Warning: #D89B35
Danger: #D95757

Dark theme:
Background: #101B16
Surface: #18251E
Primary: #C7F36B
Text: #F4F7F3

Use the colors as centralized design tokens. Do not scatter hardcoded colors throughout widgets.

### Typography

Use Inter or Manrope.

Typography must have a clear hierarchy:
- Large page titles
- Medium section headings
- Readable body text
- Small secondary labels
- Consistent number formatting

### UI style

- Premium minimalism
- Spacious layouts
- Clean surfaces
- Subtle borders
- Carefully controlled shadows
- 14–18 px corner radius for cards
- Consistent 8 px spacing grid
- Smooth but restrained animations
- Beautiful empty states
- Skeleton loading
- Clear error states
- Accessible contrast
- Responsive layouts

Avoid:
- Excessive gradients
- Excessive rounded cards
- Overloaded dashboards
- Tiny text
- Too many colors
- Decorative charts without business meaning
- Generic template appearance

Use real icons consistently.

Create reusable design components.

## Navigation

Mobile business application:

Bottom navigation:
1. Home
2. Calendar
3. Customers
4. Finance
5. More

Provide contextual access to:
- Services
- Employees
- Branches
- Analytics
- Marketing
- Reviews
- Settings

Use adaptive navigation for tablets and desktop.

## Required screens

### Authentication
- Welcome
- Login
- Registration
- OTP
- Password recovery
- Language selection

### Onboarding
- Business type selection
- Business profile
- Branch creation
- Working hours
- Service setup
- Employee invitation
- Payment settings
- Booking page publication

### Home dashboard
Show:
- Greeting
- Business name
- Today's revenue
- Today's bookings
- Pending bookings
- Upcoming appointments
- Booking chart
- Employee activity
- Quick actions

### Calendar
- Day
- Week
- Month
- Employee filters
- Branch filters
- Booking details
- Create booking
- Reschedule booking

### Booking details
- Customer
- Service
- Employee
- Branch
- Date and time
- Price
- Deposit
- Remaining balance
- Payment status
- Booking status
- Notes
- Actions

### Customers
- Customer list
- Search
- Filters
- Customer profile
- Booking history
- Financial history
- Notes
- Tags

### Services
- Service list
- Categories
- Create service
- Edit service
- Pricing
- Duration
- Deposit
- Employee assignment

### Employees
- Employee list
- Profile
- Schedule
- Services
- Performance
- Commission

### Finance
- Revenue
- Transactions
- Deposits
- Refunds
- Outstanding payments
- Financial reports

### Analytics
- Revenue charts
- Booking charts
- Customer growth
- Employee performance
- Service performance

### Settings
- Business profile
- Branches
- Staff
- Working hours
- Booking rules
- Payments
- Notifications
- Subscription
- Language
- Theme
- Security

Implement all core screens with working navigation and backend integration. Do not leave buttons that appear functional but do nothing.

---

# 22. PUBLIC CUSTOMER BOOKING EXPERIENCE

Design a separate customer-facing flow.

It should be fast, minimal, and easy to use.

Customer flow:
1. Open booking link.
2. View business profile.
3. Choose branch.
4. Choose service.
5. Choose employee.
6. Choose date.
7. Choose time.
8. Enter contact details.
9. Review booking.
10. Pay deposit if required.
11. Receive confirmation.

Use a clear step indicator.

Show price, duration, deposit, and remaining balance transparently.

Support mobile browsers.

---

# 23. ADMIN WEB EXPERIENCE

Build a desktop-first but responsive Flutter Web interface.

Sidebar:
- Overview
- Businesses
- Users
- Subscriptions
- Payments
- Plans
- Support
- Reviews
- Analytics
- Audit logs
- Settings

Design:
- Premium SaaS admin interface
- Clean tables
- Filters
- Pagination
- Search
- Detail pages
- Status badges
- Confirmation dialogs for destructive actions
- Audit trail visibility

Never implement destructive actions without appropriate authorization and confirmation.

---

# 24. BACKEND MODULE STRUCTURE

Use a clean modular architecture.

Recommended modules:

- identity
- authentication
- authorization
- tenancy
- businesses
- branches
- employees
- services
- scheduling
- bookings
- customers
- crm
- payments
- ledger
- subscriptions
- pricing
- notifications
- marketing
- loyalty
- reviews
- analytics
- support
- files
- audit
- platform-admin
- integrations
- common

Keep module boundaries clear.

Do not build one enormous service class.

Use DTOs for API contracts.

Do not expose JPA entities directly.

Use proper validation, exception handling, and transactional boundaries.

Use domain events for decoupled business workflows where useful.

Document important architecture decisions.

---

# 25. API DESIGN

Use REST APIs with consistent conventions.

Example:

/api/v1/auth/*
/api/v1/businesses/*
/api/v1/branches/*
/api/v1/employees/*
/api/v1/services/*
/api/v1/bookings/*
/api/v1/customers/*
/api/v1/calendar/*
/api/v1/payments/*
/api/v1/subscriptions/*
/api/v1/analytics/*
/api/v1/notifications/*
/api/v1/admin/*

Requirements:
- Versioned APIs
- Pagination
- Filtering
- Sorting
- Validation
- Consistent error responses
- OpenAPI documentation
- Idempotency where needed
- Rate limiting
- Authorization checks
- Request correlation IDs

Never return internal stack traces or sensitive infrastructure information to clients.

---

# 26. DATABASE DESIGN

Use PostgreSQL.

Create proper normalized relational tables.

Core entities:

- users
- user_sessions
- roles
- permissions
- user_business_memberships
- businesses
- business_settings
- branches
- branch_hours
- employees
- employee_branches
- employee_services
- employee_shifts
- employee_time_off
- service_categories
- services
- service_prices
- customers
- customer_tags
- customer_notes
- bookings
- booking_items
- booking_status_history
- booking_payments
- payment_transactions
- refunds
- financial_ledger_entries
- subscriptions
- subscription_plans
- subscription_entitlements
- invoices
- promo_codes
- loyalty_accounts
- loyalty_transactions
- reviews
- notifications
- notification_templates
- support_tickets
- support_messages
- file_metadata
- audit_logs

Add:
- Foreign keys
- Unique constraints
- Check constraints
- Appropriate indexes
- Tenant-aware indexes
- Created/updated timestamps
- Soft deletion only where justified

Use Flyway migrations.

Do not modify production schema manually.

Do not store monetary amounts as floating-point values.

Use explicit timezone handling and store timestamps consistently, preferably as UTC instants with timezone context where needed.

Add database migration tests.

---

# 27. SECURITY AND PRIVACY

Implement security from the beginning.

Requirements:
- OWASP ASVS-inspired security practices
- Secure authentication
- Tenant isolation
- RBAC
- Input validation
- SQL injection protection
- XSS protection
- CSRF protection where applicable
- CORS restrictions
- Rate limiting
- Secure file upload
- Webhook signature verification
- Secret management
- Audit logs
- Sensitive data masking
- Encryption in transit
- Secure password storage
- Backup and recovery procedures

Prepare privacy functionality:
- Consent
- Data export
- Account deletion
- Retention policies
- Marketing opt-out

Review applicable Kazakhstan personal data requirements and prepare the product for future international privacy compliance.

Never claim legal compliance without a proper legal assessment.

---

# 28. PERFORMANCE AND SCALABILITY

Design for gradual growth.

Initial target:
- 1,000 businesses
- 10,000 employees
- 100,000 customers
- 1,000,000 bookings

These are design targets, not claims of achieved capacity.

Implement:
- Pagination
- Efficient database queries
- Proper indexes
- Avoid N+1 queries
- Connection pooling
- Background processing
- Caching only where justified
- Optimized file storage
- Efficient analytics queries

Measure performance instead of assuming it.

Add load-test scenarios for:
- Availability lookup
- Booking creation
- Booking confirmation
- Calendar retrieval
- Customer search
- Dashboard analytics

---

# 29. OBSERVABILITY AND OPERATIONS

Implement:
- Structured JSON logs
- Request IDs
- Error tracking integration points
- Health checks
- Readiness checks
- Liveness checks
- Metrics
- Database monitoring
- External integration monitoring
- Audit events

Use Spring Boot Actuator.

Do not log passwords, access tokens, payment credentials, or sensitive customer data.

Create operational documentation:
- Deployment
- Monitoring
- Incident response
- Backup
- Restore
- Database migration
- Rollback

---

# 30. TESTING STRATEGY

Testing is mandatory.

Backend:
- Unit tests
- Service tests
- Repository tests
- API integration tests
- Security tests
- Tenant isolation tests
- Payment tests
- Booking concurrency tests
- Migration tests

Flutter:
- Unit tests
- Widget tests
- State management tests
- Navigation tests
- Localization tests
- Form validation tests

End-to-end:
- Registration
- Business onboarding
- Create service
- Add employee
- Publish booking page
- Customer creates booking
- Deposit payment
- Booking confirmation
- Rescheduling
- Cancellation
- Refund
- Appointment completion
- Subscription upgrade

Use Testcontainers for integration tests where possible.

Do not mark tests as passed unless they were actually executed.

Fix test failures rather than disabling or weakening tests to obtain a green result.

---

# 31. CI/CD AND DEPLOYMENT

Create:
- Dockerfiles
- Docker Compose
- GitHub Actions workflows
- Backend build pipeline
- Flutter test pipeline
- Flutter build pipeline
- Static analysis
- Dependency checks
- Container image build
- Container registry publishing
- Kubernetes deployment templates
- Environment configuration templates

Environments:
- LOCAL
- TEST
- STAGING
- PRODUCTION

Use separate configuration and secrets for every environment.

Do not deploy to production automatically during initial development.

Create documented deployment and rollback procedures.

Do not commit real secrets.

---

# 32. DOCUMENTATION

Create and maintain:

docs/
  PRODUCT_OVERVIEW.md
  PRODUCT_REQUIREMENTS.md
  SYSTEM_ARCHITECTURE.md
  ARCHITECTURE_DECISIONS.md
  DATABASE_SCHEMA.md
  API_CONTRACTS.md
  TENANCY_AND_SECURITY.md
  BOOKING_ENGINE.md
  PAYMENT_ARCHITECTURE.md
  SUBSCRIPTION_MODEL.md
  DESIGN_SYSTEM.md
  FLUTTER_ARCHITECTURE.md
  BACKEND_MODULES.md
  TEST_STRATEGY.md
  DEPLOYMENT.md
  OPERATIONS.md
  BACKUP_AND_RECOVERY.md
  SECURITY_REVIEW.md
  RELEASE_CHECKLIST.md
  IMPLEMENTATION_STATUS.md

Documentation must reflect actual implementation, not imagined future functionality.

---

# 33. IMPLEMENTATION EXECUTION RULES

You must work autonomously.

Follow this execution process internally:

1. Inspect the development environment.
2. Check installed Java, Gradle, Flutter, Dart, Docker, and Git.
3. Check the workspace and protect any existing projects.
4. Create the new ORLEU project structure.
5. Define architecture and design system.
6. Build backend foundations.
7. Build database migrations.
8. Implement authentication and tenancy.
9. Implement the booking engine.
10. Implement CRM, employees, branches, and services.
11. Implement payments and ledger foundations.
12. Implement subscriptions.
13. Implement notifications.
14. Build the Flutter application.
15. Build public booking pages.
16. Build platform administration.
17. Add analytics.
18. Add automated tests.
19. Add CI/CD and infrastructure.
20. Run builds and tests.
21. Fix defects.
22. Update documentation.
23. Produce a final implementation report.

Do not stop after step 1 or 2.

Do not return only a plan.

Do not generate large amounts of placeholder code and claim the application is complete.

Implement complete vertical workflows from UI to API to database.

Where credentials or external accounts are unavailable:
- Implement the integration interface.
- Implement a safe sandbox or mock adapter.
- Document the missing external configuration.
- Never fabricate successful external transactions.

Do not silently skip features. Clearly mark anything that cannot be implemented because of missing credentials or external dependencies.

Do not remove tests just to make the build pass.

Do not use fake business statistics in production interfaces.

Use demo seed data only in clearly identified development/demo environments.

---

# 34. DEFINITION OF DONE

The product is not complete merely because it compiles.

The core release must demonstrate these real workflows:

A. A business owner can register and create a business.

B. The owner can configure branches, working hours, services, and employees.

C. The owner can publish a public booking page.

D. A customer can book an available appointment without installing the application.

E. The booking engine prevents double booking.

F. The business can confirm, reschedule, cancel, and complete appointments.

G. The customer can pay a deposit through a configured provider or use a clearly identified sandbox payment flow.

H. The business can see the remaining balance.

I. The owner can manage customers and employees.

J. The owner can view meaningful financial and booking analytics.

K. Subscription entitlements are enforced by the backend.

L. Tenant isolation is covered by automated tests.

M. The Flutter app has working authentication, navigation, localization, and API integration.

N. The admin interface can manage platform-level entities according to permissions.

O. CI builds and automated tests execute successfully.

Only report functionality as complete when it has been implemented and verified.

---

# 35. FINAL DELIVERY REPORT

At the end, create:

docs/IMPLEMENTATION_STATUS.md

Include:

1. Implemented modules
2. Implemented Flutter screens
3. Implemented backend APIs
4. Database schema and migrations
5. Architecture decisions
6. Security implementation
7. Test results
8. Build results
9. Known defects
10. Missing external credentials
11. Required environment variables
12. Local startup instructions
13. Test deployment instructions
14. Remaining production blockers

Clearly distinguish:
- IMPLEMENTED AND TESTED
- IMPLEMENTED BUT NOT FULLY TESTED
- PARTIALLY IMPLEMENTED
- NOT IMPLEMENTED
- BLOCKED BY EXTERNAL DEPENDENCY

Do not declare production readiness without real end-to-end verification, security review, payment-provider verification, backup/restore testing, and deployment validation.

---

# FINAL INSTRUCTION

Build ORLEU as a serious international SaaS product.

Think like a founder, architect, product designer, and senior engineering team.

Prioritize:
1. Exceptional user experience.
2. Reliable booking and scheduling.
3. Correct financial operations.
4. Strict multi-tenant security.
5. Clean architecture.
6. Excellent Flutter design.
7. Real backend functionality.
8. Maintainability.
9. Testability.
10. Scalability.

Make the interface beautiful, the backend reliable, and the business logic correct.

Do not build a superficial demo.

Do not stop at a plan.

Do not wait for intermediate approval.

**Start implementing ORLEU now.**

**ORLEU — Your Business. Your Growth.**
