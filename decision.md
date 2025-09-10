# Merchant Integration Design Decisions

## Core Architecture Decisions

### Multi-Tenant Implementation
- **Decision:** Single `merchants` table + `merchant_tenants` junction table approach
- **Rationale:** One merchant account can serve multiple tenants while maintaining clean data relationships
- **Alternative Rejected:** Separate merchant record per tenant (would complicate authentication)

### Menu Data Sharing
- **Decision:** When new tenant enrolls existing merchant, they get access to all existing menu data
- **Rationale:** Simplifies onboarding and menu management for merchants
- **Implementation:** No item-level tenant restrictions needed

### Authentication Pattern
- **Decision:** Single login for merchants (following customers table pattern)
- **Rationale:** Hybrid approach with junction table for tenant access, merchants see orders from all tenants with tenant badges
- **Alternative Rejected:** Separate logins per tenant (would complicate user experience)

### Order Status Tracking
- **Decision:** Dual status system - existing `status` + new `merchant_status` column
- **Rationale:** Supports both operational workflow and merchant-specific workflow (new/confirmed/for_pickup)
- **Implementation:** Two columns in orders table

### Pricing Flexibility
- **Decision:** Items can have different pricing per tenant via JSONB field
- **Rationale:** Same menu item can have different prices for different tenants (e.g., Big Mac $5 for Tenant A, $6 for Tenant B)
- **Implementation:** `tenant_pricing` JSONB field in merchant_items

## Table Structure Decisions

### Schema Simplification
- **Decision:** 4-table minimal approach instead of original 6-table plan
- **Rationale:** Avoid over-engineering while capturing all requirements
- **Tables:** merchants, merchant_tenants, merchant_categories, merchant_items

### Categories vs Items Separation
- **Decision:** Separate merchant_categories and merchant_items tables
- **Rationale:** Categories can exist independently before items are added, enables proper menu organization
- **Alternative Rejected:** Flattened structure with category as string field (loses management capabilities)

### Modifier Storage
- **Decision:** Store modifiers as JSONB array in merchant_items table
- **Rationale:** Item-specific modifiers with optional pricing, avoids additional table complexity
- **Format:** `[{"name": "Extra Cheese", "price": 2.00}]`

## Service Integration Decisions

### Service Type Scope
- **Decision:** Merchants only serve 'food_delivery' and 'shopping' service types
- **Rationale:** Aligns with merchant-mediated services in platform architecture

### Business Hours Management
- **Decision:** Global business hours with availability toggle
- **Rationale:** Merchants can pause operations or mark temporarily unavailable across all tenants

### Inventory Management
- **Decision:** Simple availability on/off per item, no quantity tracking
- **Rationale:** Controlled feature set for initial implementation

## Data Relationships

### Merchant-Tenant-Hub Relationship
- **Decision:** 1 merchant per hub per tenant via junction table
- **Rationale:** Clear operational boundaries while allowing multi-tenant service

### Cross-Tenant Merchant Sharing
- **Decision:** No additional schema changes needed for merchant sharing between tenants
- **Rationale:** Existing `merchant_tenants` junction table already supports the scenario where one merchant serves multiple tenants
- **Implementation:** Merchant A enrolled with Tenant A can be enrolled with Tenant B by simply adding another record to `merchant_tenants` table
- **Key Benefits:** 
  - Single merchant login/account (no duplicate onboarding)
  - Same menu items available across tenants
  - Independent tenant-specific pricing via existing `tenant_pricing` JSONB field
  - Proper order attribution via existing `orders.merchant_id` + `orders.tenant_id` structure
- **Alternative Rejected:** Complex approval workflows, revenue sharing tracking, and enrollment method tracking deemed unnecessary for core business requirements

### Menu Item Pricing
- **Decision:** Base price in merchant_items + tenant-specific overrides in JSONB
- **Rationale:** Flexible pricing model supporting same item at different prices per tenant

### Order Integration
- **Decision:** Change order_details.restaurant_id to merchant_id
- **Rationale:** Align with new merchant structure, maintain referential integrity

## Security and Performance

### Data Isolation
- **Decision:** Merchants see only their own data across all tenants
- **Implementation:** RLS policies on merchant tables

### Expected Scale
- **Decision:** ~30 merchants per tenant, ~30-50 items per merchant
- **Rationale:** Guides index strategy and performance optimizations

### Schema Architecture Validation
- **Decision:** Current merchant system design confirmed as optimal for cross-tenant sharing requirements
- **Validation Date:** 2025-09-10
- **Schema Status:** No modifications required - existing structure supports all identified merchant sharing scenarios
- **Performance Impact:** Zero - no additional tables, columns, or indexes needed

## Implementation Approach

### Migration Strategy
- **Decision:** Migrate existing restaurant_id references to new merchant structure
- **Rationale:** Maintain backward compatibility while adopting new architecture

### Development Phases
1. Core merchant infrastructure (authentication, tenant access)
2. Menu system (categories, items with pricing/modifiers)
3. Order integration (status tracking, reference updates)
4. Security and performance (RLS policies, indexes)

---

## Platform Architecture & Database Design Decisions

### Database Technology & Multi-Tenancy
- **Decision:** PostgreSQL 15+ with PostGIS extension, single database with tenant isolation
- **Rationale:** ACID compliance critical for financial data (COD transactions), PostGIS provides superior geospatial capabilities for delivery zones and routing
- **Multi-tenancy Implementation:** Row Level Security (RLS) with tenant_id filtering ensures complete data separation
- **Scaling Strategy:** Read replicas at 6K+ orders, horizontal scaling at 15K+ orders with PgBouncer connection pooling

### Peak Hours & Operational Database Load
- **Decision:** Design for dual-peak operational pattern with holiday/weather variations
- **Primary peaks:** 11am-1pm and 5pm-7pm daily requiring peak database capacity
- **Weather scaling:** Infrastructure must handle 2-3x normal capacity during extreme weather (typhoons/rain seasons)
- **Holiday adjustments:** Flexible auto-scaling capabilities for variable demand patterns
- **Rationale:** Provincial markets experience significant weather-driven demand spikes, proactive scaling prevents service degradation

### Real-time Architecture & Concurrent Connections
- **Decision:** Adaptive real-time updates with provincial market optimizations
- **Concurrent connections:** 2,475 at 10K orders (much lower than initial 31K estimate)
- **Base frequency:** 30-second location updates during active delivery with optimization triggers
- **Provincial adjustments:** Offline-first design for unreliable connectivity
- **Rationale:** Realistic usage patterns show lower concurrent demand than Metro Manila, conservative estimates prevent over-provisioning

### Location Tracking & Storage Architecture
- **Decision:** Hybrid Redis + PostgreSQL approach with adaptive frequency updates
- **Implementation:** Redis for real-time active rider locations (30-45 second intervals, 1-hour TTL), PostgreSQL for compressed route summaries
- **Optimization:** Adaptive frequency (Idle: 2-3 min, Active delivery: 30 sec, At stops: 10 sec) reduces database writes by 70-80%
- **Rationale:** Balances real-time accuracy with cost efficiency, scales to 4x volume without major architecture changes

### Performance Optimization Strategy
- **Decision:** Multi-layered optimization targeting 70-80% cost reduction
- **Geofencing:** Stop updates when riders stationary (50m threshold, 100m movement trigger)
- **Batching:** Group 3-5 location points per API call to reduce database connections
- **Route compression:** Google Maps polyline format achieves 90% storage reduction vs individual GPS points
- **Tiered caching:** Hot (Redis), Warm (Redis), Cold (PostgreSQL) data strategy
- **Rationale:** Aggressive optimization necessary for provincial market profitability, batching reduces database load significantly

### Data Retention Strategy
- **Location tracking:** 1 week operational data, compressed routes permanent
- **Order history:** 1 month to 1 year (client-configurable based on sophistication)
- **Financial data:** Permanent retention (compliance requirement)
- **Performance analytics:** Up to 1 year (client-configurable)
- **Rationale:** Different clients have varying retention needs; compliance requirements non-negotiable for financial data

### Admin Dashboard Concurrent Load Planning
- **Decision:** Variable dispatcher model based on tenant priority/volume levels
- **Staffing ratios:** Small tenants (1 dispatcher), Medium (2-3), Large (3+), Average: 1.5 dispatchers per tenant
- **Infrastructure sizing:** Peak concurrent usage during meal rush periods (11am-1pm, 5pm-7pm)
- **Database impact:** Connection pooling sized for 1.5 dispatchers × tenant count × peak multiplier
- **Rationale:** Infrastructure sizing based on realistic dispatcher staffing patterns and peak coverage requirements

### Provincial Market Adaptations
- **Decision:** React Native with SQLite-based offline-first architecture for unreliable provincial connectivity
- **Implementation:** Priority-based sync queue - Financial (100 attempts) > Task completion (50) > Status (50) > Media (20) > Location (20)
- **COD handling:** 70-80% COD support vs 50% in Metro Manila requires robust cash collection and reconciliation
- **Infrastructure:** Local CDN nodes and bandwidth optimization for cost-effective service delivery
- **Rationale:** Provincial markets have fundamentally different operational requirements, higher COD usage, unreliable connectivity

### Tenant Onboarding & Growth Phases
- **Decision:** Phased rollout starting at 3,000 orders/day with select tenants
- **Phase 1:** 42 top-performing tenants (Highest + High priority levels) for risk reduction
- **Phase 2:** All 64 existing tenants + 20% app adoption boost (5,500 orders)
- **Phase 3:** New tenant acquisition + direct restaurants (6,000 orders)
- **Phase 4:** Geographic expansion to 10,000 orders over 2 years
- **Rationale:** Gradual infrastructure scaling prevents operational overwhelm, enables optimization before full deployment

### Business Model & Schema Impact
- **Decision:** Delivery services as primary clients (90-95%) with selective direct restaurant partnerships (5-10%)
- **Primary model:** Partner with existing local delivery services (leverages proven demand)
- **Secondary model:** Direct restaurant clients for online ordering (growth opportunity)
- **Schema considerations:** Separate entity structure for direct clients, no merchant app needed initially
- **Rationale:** Balanced approach reduces dependence on single business model while maintaining operational focus

### Infrastructure Scaling Checkpoints
- **3,000 orders:** Single-instance architecture ($400-500/month)
- **5,500 orders:** Upgraded database specs ($600-800/month)
- **6,000 orders:** Read replicas + load balancing ($800-1,000/month)
- **10,000 orders:** Horizontal scaling + clustering ($1,500-2,000/month)
- **Rationale:** Clear upgrade paths prevent performance degradation with cost scaling aligned to revenue growth

### Service Type Architecture
- **Decision:** Support 5 service types with 80% Food Delivery, 15% Pickup & Delivery, 5% Shopping focus
- **Rationale:** Based on actual data from 64 existing tenants generating 4,568 orders/day in provincial markets
- **Schema Impact:** Unified order processing system handles all service types through single orders table structure

### Service Fulfillment Time Standards
- **Decision:** Service-specific fulfillment time standards reflecting operational realities
- **Food delivery:** 55-65 minutes total (30min prep + 10min pickup + 15-25min travel)
- **Pickup & delivery:** 25-45 minutes (5min pickup + 20-40min travel distance-dependent)
- **Shopping:** 55-95 minutes (30-60min shopping + 10min pickup + 15-25min travel)
- **Database impact:** Status tracking timestamps and SLA monitoring for performance analytics
- **Rationale:** Realistic timing prevents over-promising, provincial travel times longer, enables proper performance tracking

### Customer Behavior Modeling
- **Food delivery:** 4-6 tracking sessions per order (vs 8-12 in Metro Manila)
- **Pickup & delivery:** 2-3 sessions per order
- **Shopping:** 1-2 sessions per order
- **Session duration:** 1-2 minutes average (task-focused checking)
- **Rationale:** Provincial customers less anxious about tracking, intermittent connectivity leads to shorter sessions

---

*These decisions provide the foundation for implementing merchant functionality with minimal complexity while supporting all identified requirements.*