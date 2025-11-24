# Benefits Coverage Assistant — AI-Powered, Compliant, Gracefully Degrading

**TL;DR:** A safe, **assistive-only** benefits chat interface that answers coverage questions using structured rule data and AI, falls back to **human support tickets** when uncertain, and tracks every interaction for audit. It's **feature-flagged**, **PII-conscious**, and requires **no schema-breaking changes**. Built to explore how Canadian benefits platforms can increase employee engagement while maintaining trust and compliance.

## Why this exists (business lens)

Today, benefits are **under-used** because employees do not know what is covered, how much is left, or where to go. That creates **avoidable HR tickets** ("Is massage covered?"), slower claim submission, and weak perceived value—bad for activation and renewals in a new market.

If a "coverage answer" is wrong, ambiguous, or too slow, **trust drops fast**: admins become the help desk again, employees stop engaging, and the "fully digital, low-friction" promise takes a reputational hit. In Canada, you also have **provincial compliance and PHI privacy scrutiny**—errors here are not just UX bugs.

This prototype shows a **low-risk path** to:

* **Engagement:** move coverage discovery from email/phone → **instant, self-serve chat**
* **Accuracy:** ground answers in structured benefit rules with version tracking
* **Safety:** never promise reimbursement; always cite sources; fall back to humans
* **Privacy:** redact PII before logging; no raw health data in AI prompts
* **Trust:** every interaction is logged with confidence scores and metadata

## What it does (product behavior)

When an employee asks a benefits question (e.g., "How much massage therapy is left?"), the system:

1. **Determines intent** using pattern matching and AI classification
2. **Dispatches to executor functions** that fetch coverage rules and balances from structured data
3. **Generates a natural language response** citing specific rules, limits, and disclaimers
4. **Falls back to support ticket creation** if AI is disabled, errors occur, or confidence is low
5. **Logs every interaction** with metadata (intent, confidence, function used, PII redaction status)

**Assistive posture:**
- Never guarantees reimbursement ("coverage" ≠ "claim approval")
- Always includes disclaimers about claim submission rules
- Surfaces rule version IDs so admins can track drift
- Gracefully degrades: AI failure → human ticket, not broken experience

**Privacy & compliance:**
- PII redaction patterns (names, phone numbers) applied before external API calls
- Provincial rule versioning (ON, BC, etc.) built into data model
- Feature flag to disable AI entirely (`AI_CHAT_ENABLED=false`)

## Success criteria (if this shipped as a pilot)

* **Self-serve resolution rate** ≥ 60% (questions answered without ticket)
* **Median response time** ≤ 3s for coverage lookups
* **Employee satisfaction (CSAT)** ≥ 4.2/5 for AI responses
* **Admin ticket volume** for coverage questions ↓ 40%
* **Zero compliance incidents** related to incorrect coverage guidance
* **Rule staleness alerts** triggered before 90-day drift threshold
* **PII redaction coverage** ≥ 95% of user messages scanned

## Architecture at a glance

**Service Layer:**
- `SupportService`: Orchestrates AI processing vs ticket creation
- `AiService`: Coordinates intent → dispatch → response generation
- `IntentDeterminationService`: Classifies user query into function call
- `ResponseGenerationService`: Generates natural language from structured data
- `FunctionDispatcher`: Plugin system for executor functions

**Executor Functions:**
- `GetBenefitCoverageExecutor`: Fetches coverage rules for a category/province
- `GetCoverageBalanceExecutor`: Retrieves remaining balance for a user

**Safety & Compliance Modules:**
- `PiiRedaction`: Regex-based redaction before AI API calls (names, phones, emails)
- `FeatureFlags`: Environment-based kill switch for AI (`AI_CHAT_ENABLED`)

**Data Models:**
- `Profile`: User with province (determines applicable rules)
- `Benefit`: Versioned coverage rules (JSONB) per category/province
- `CoverageBalance`: User-specific remaining amounts + reset dates
- `ChatMessage`: Full conversation log with confidence metadata
- `SupportTicket`: Fallback queue with priority, status, context

**UI:**
- Stimulus.js chat controller with streaming message display
- Tailwind CSS for responsive, accessible interface
- Real-time ticket creation feedback

## Run it locally (quick start)

```bash
git clone https://github.com/[your-org]/benefits_coverage_assistant
cd benefits_coverage_assistant
bundle install
rails db:create db:migrate db:seed

# Set your OpenAI API key (required for AI mode)
export OPENAI_API_KEY="sk-..."

# Run the app
bin/dev

# Optional: disable AI to test ticket fallback
AI_CHAT_ENABLED=false bin/dev
```

**Access the dashboard:**
```
http://localhost:3000/dashboard
```

**Sample queries to test:**
- "How much massage therapy coverage do I have left?"
- "Is acupuncture covered in Ontario?"
- "What's my remaining balance for physiotherapy?"
- "Do I need a referral for a chiropractor?"

## Top risks & safety rails

### Risk 1: Rule accuracy & drift
**Mitigation:**
- `rule_version_id` tracked on every benefit rule and balance
- `stale?` scope flags rules not updated in 90+ days
- Responses cite version IDs so admins can audit
- **Roadmap:** Automated alerts for stale rules

### Risk 2: Scope creep into adjudication
**Mitigation:**
- All responses include disclaimer: "Coverage ≠ guarantee of reimbursement"
- Never use language like "you will be reimbursed"
- Always direct to claims process for actual submissions
- **Roadmap:** Legal-reviewed response templates per province

### Risk 3: Provincial localization gaps
**Mitigation:**
- Benefits data model requires `province` field
- Executors filter by `profile.province`
- Seed data includes ON, BC examples
- **Roadmap:** Provincial tax treatment notes, regulatory links

### Risk 4: Privacy & PHI handling
**Mitigation:**
- PII redaction before OpenAI API calls (names, phones)
- Coverage balances stored encrypted at rest (production)
- No raw health claims data in this prototype
- **Roadmap:** PHIPA/PIPEDA audit, data residency controls

### Risk 5: Provider data quality
**Mitigation:**
- This prototype does NOT include provider search
- Future feature would require verified data partnerships
- **Roadmap:** Provider API integration with SLA + freshness guarantees

### Risk 6: Reliability & latency
**Mitigation:**
- Automatic fallback to ticket creation on AI timeout/error
- Function executors use indexed DB queries (< 50ms)
- **Roadmap:** Response caching, retry logic, circuit breakers

### Risk 7: Abuse & spam
**Mitigation:**
- Rate limiting (to be implemented in production)
- All messages tied to authenticated profiles
- **Roadmap:** CAPTCHA for public endpoints, abuse detection

### Risk 8: LLM hallucination
**Mitigation:**
- AI never invents coverage amounts; it only formats executor results
- Confidence scores logged for every response
- Low-confidence queries → human escalation
- **Roadmap:** Human-in-the-loop review for responses < 0.7 confidence

### Non-negotiable safety rails
- **Feature-flagged:** `AI_CHAT_ENABLED` env var for instant rollback
- **Suggestive, not dispositive:** "This is guidance; submit claims for actual coverage"
- **No schema breaking changes:** Uses JSONB for flexibility
- **No external PHI egress** (in production, OpenAI would be replaced with on-prem LLM)
- **Audit trail:** Every chat + ticket logged with metadata

## What's in here (tech map)

**Models:**
- `Profile` — user identity + province
- `Benefit` — versioned coverage rules (category + province + JSONB structure)
- `CoverageBalance` — user-specific remaining amounts
- `ChatMessage` — conversation log with AI metadata
- `SupportTicket` — fallback queue with status/priority

**Services:**
- `SupportService` — orchestrates AI vs ticket flow
- `AiService` — intent → dispatch → response pipeline
- `IntentDeterminationService` — query classification
- `ResponseGenerationService` — natural language generation
- `FunctionDispatcher` — plugin system for executors

**Executors:**
- `GetBenefitCoverageExecutor` — fetches coverage rules
- `GetCoverageBalanceExecutor` — retrieves user balances

**Modules:**
- `PiiRedaction` — regex-based PII scrubbing
- `FeatureFlags` — environment-based toggles
- `FunctionDispatcher` — YAML-driven function registry

**Controllers/Views:**
- `DashboardController` — chat UI + message creation API
- Stimulus `chat_controller.js` — real-time message handling

## What's needed for production readiness

### 1. Security & Compliance
- [ ] **PHIPA/PIPEDA audit** with legal counsel
- [ ] **Data residency controls** (Canada-only storage + processing)
- [ ] **Encryption at rest** for coverage balances (not just in transit)
- [ ] **Role-based access control** for admin ticket queue
- [ ] **Penetration testing** of chat API endpoints
- [ ] **Rate limiting** (per user, per IP)
- [ ] **CAPTCHA** for public-facing endpoints
- [ ] **CSA STAR / SOC 2** compliance for cloud infrastructure

### 2. Data Quality & Governance
- [ ] **Benefit rule versioning workflow** (admin UI for updates + approval)
- [ ] **Automated staleness alerts** (Slack/email when rules > 90 days old)
- [ ] **Rule change audit log** (who updated what, when)
- [ ] **Multi-plan support** (currently single plan; need plan tiers)
- [ ] **Rider/amendment tracking** (plan addons, mid-year changes)
- [ ] **Provincial tax treatment notes** (taxable vs non-taxable benefits)
- [ ] **Claims data integration** (sync balances with actual claims system)

### 3. AI Safety & Quality
- [ ] **Human-in-the-loop review** for low-confidence responses (< 0.7)
- [ ] **Legal-reviewed response templates** per province
- [ ] **A/B testing framework** (AI responses vs ticket-only control group)
- [ ] **Confidence calibration** (tune thresholds per intent type)
- [ ] **Hallucination detection** (validate AI output against source data)
- [ ] **On-premises LLM** (replace OpenAI with self-hosted Llama/Mistral)
- [ ] **Explainability logging** (which rule/version led to response)

### 4. Operational Excellence
- [ ] **Monitoring & alerting** (error rates, latency, ticket volume)
- [ ] **Circuit breakers** for external dependencies
- [ ] **Response caching** (common queries cached 5–15 min)
- [ ] **Retry logic** with exponential backoff
- [ ] **Admin dashboard** (ticket queue, metrics, rule health)
- [ ] **Bulk ticket resolution** (mark resolved, add notes)
- [ ] **Escalation SLAs** (urgent tickets → 2hr, normal → 24hr)
- [ ] **Customer satisfaction (CSAT)** surveys post-resolution

### 5. Scalability & Performance
- [ ] **Database migration** from SQLite → PostgreSQL
- [ ] **Read replicas** for coverage lookups
- [ ] **Background job queue** (Sidekiq/GoodJob) for ticket processing
- [ ] **CDN** for static assets
- [ ] **Horizontal scaling** (load balancer + multiple app servers)
- [ ] **Database connection pooling** (PgBouncer)
- [ ] **API rate limiting** (Redis-backed throttling)

### 6. User Experience & Accessibility
- [ ] **Multilingual support** (French required for Quebec)
- [ ] **WCAG 2.1 AA compliance** (screen readers, keyboard nav)
- [ ] **Mobile app** (React Native or native iOS/Android)
- [ ] **Email notifications** (ticket created, resolved)
- [ ] **SMS opt-in** for urgent ticket updates
- [ ] **In-chat file uploads** (receipts, referral letters)
- [ ] **Provider search** (verified directory with SLA)

### 7. Testing & Quality Assurance
- [ ] **Load testing** (1000+ concurrent users)
- [ ] **Chaos engineering** (simulate DB failures, API timeouts)
- [ ] **Regression test suite** (critical user flows)
- [ ] **Contract testing** for function executors
- [ ] **Fuzz testing** for PII redaction edge cases
- [ ] **Accessibility audit** (third-party WCAG validation)

### 8. Legal & Disclaimers
- [ ] **Terms of Service** with liability limits
- [ ] **Privacy Policy** (data retention, third-party sharing)
- [ ] **Per-province disclaimers** (ON: PHIPA notice, BC: PIPA, etc.)
- [ ] **"Not financial/medical advice"** footer on every response
- [ ] **Regulatory filings** (if required by provincial insurance boards)

## Testing

```bash
# Run full test suite
bundle exec rspec

# Run specific test files
bundle exec rspec spec/services/support_service_spec.rb
bundle exec rspec spec/services/ai_service_spec.rb

# Run with coverage report
COVERAGE=true bundle exec rspec
```

---

**Remember:** This is an **assistive prototype**, not a production claims adjudication system. Coverage guidance ≠ guarantee of reimbursement. Always direct users to submit claims through official channels.
