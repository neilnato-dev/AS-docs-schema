# Airship Lite - Complete Knowledge Base & Design Decisions

## Project Overview

**Airship Lite** is a multi-tenant delivery management platform targeting the Philippines and Southeast Asian markets. It consists of three main applications:

- **Admin Dashboard** - Used by clients (couriers, restaurants, retailers, etc.)
- **Rider App** - React Native app for delivery personnel with offline-first architecture
- **Customer App** - Progressive Web App for end customers
- **Merchant App** - Mobile App for merchant for receiving orders

**Target Market**: Local businesses transitioning from traditional channels (phone, SMS, Facebook Messenger) to digital ordering and dispatch solutions.

---

## Business Requirements & Decisions

### **Multi-Tenancy & Scale**

- **Approach**: Soft isolation using `tenant_id` in all tables
- **Scale Target**: 50 tenants Q1, 150 tenants Year 1, 20% monthly growth
- **Hub Operations**: Strict hub separation - riders cannot work across hubs
- **Geographic Expansion**: Philippines first, then Southeast Asia, then broader Asia

### **Service Types Supported**

The platform supports 5 service types with shared UI but different data requirements:

1. **Food Delivery** - Restaurant orders with menu items
2. **Pickup & Delivery** - Point-to-point package delivery
3. **Shopping Services (Pabili)** - Personal shopping with product catalogs
4. **Errands (Pasuyo)** - Task-based services (bill payments, documents, etc.)
5. **Transportation** - Ride-hailing like Uber/Grab

**Key Decision**: Single `orders` table for all service types with service-specific data in hybrid approach (structured columns + JSONB).

### **Order Volume & Performance**

- **Total Orders**: 10,000 orders/day across ALL tenants (not per tenant)
- **Per Tenant Average**: ~67 orders/day per tenant
- **Peak Hours**: 1,000 orders/hour total system-wide
- **Location Updates**: 450K location updates/hour (3,750 total riders × 120 updates/hour)
- **Real-time Connections**: 31K concurrent Socket.io connections

### **Multi-Hub Operations**

- **Hub Transfers**: Supported for pickup/delivery service only
- **Transfer Process**: Hub A → Hub B → Hub C (multi-hop supported)
- **Transfer Tracking**: Orders track `origin_hub_id`, `destination_hub_id`, `transfer_sequence`
- **Hub Isolation**: Strict separation - no cross-hub processing, each hub operates independently
- **Zone Overlaps**: Allowed with priority-based assignment (1=highest priority, wait for available riders)

---

## Technical Architecture Decisions

### **Database Technology**

- **Primary Database**: PostgreSQL 15+ with PostGIS extension
- **Rationale**: Multi-tenancy support, geospatial capabilities, ACID compliance for financial data
- **Scale Approach**: Single database with strategic indexing, read replicas for analytics
- **Cloud Provider**: AWS RDS with managed services

### **Real-time & Location Tracking**

- **Architecture**: Hybrid Redis + PostgreSQL approach
- **Location Frequency**: 30-45 second intervals during active delivery
- **Real-time Storage**: Redis (1-hour expiry for active tracking)
- **Historical Storage**: Compressed route summaries in PostgreSQL
- **Location Accuracy**: 50m threshold for delivery confirmation
- **Data Retention**: 7 days for location data, permanent for business data

### **Offline-First Mobile Architecture**

- **Framework**: React Native + TypeScript with Zustand state management
- **Local Database**: SQLite for offline sync queue
- **Sync Strategy**: Priority-based infinite retry system
- **Atomic Operations**: Task completion + photo upload must both succeed
- **Priority Levels**:
  1. Critical Financial (COD, payments) - 100 max attempts
  2. Task Completion (delivery confirmations) - 50 max attempts
  3. Status Updates (order status changes) - 50 max attempts
  4. Media Uploads (photos, documents) - 20 max attempts
  5. Location Data (GPS tracking) - 20 max attempts

---

## Data Model Design Decisions

### **Service-Specific Data Storage**

**Decision**: Hybrid approach with structured columns + JSONB

- **Critical queryable fields**: Separate columns (restaurant_id, vehicle_type, passenger_count, etc.)
- **Flexible data**: JSONB `additional_data` field with schema versioning
- **Rationale**: Balance between query performance and flexibility for future service types

### **Product & Menu Management**

- **Scope**: Hub-specific products (no sharing across hubs)
- **Availability**: Manual toggle (priority) + time-based schedules (simple time slots)
- **Pricing**: Per-service-type configuration, no complex surge logic
- **Inventory**: Status-based only (active/inactive), no quantity tracking initially

### **Pricing System**

**Simplified to two models per service type**:

- **Flat Rate**: Fixed charge regardless of distance/time
- **Base + Distance**: `base_fee + (distance × per_km_rate)`
- **Removed Complexity**: No night differential, no automatic surge, no complex rule combinations
- **Time-based Pricing**: Pricing schedules can activate different rates by time (e.g., 7pm onwards)

### **Order Status Management**

**Dual Status System Recommended**:

- **Operational Status**: For business workflow (`placed`, `confirmed`, `processing`, `assigned`, `picked_up`, `delivered`, `cancelled`, `in_transit_to_hub`, `arrived_at_hub`)
- **Customer Status**: For UI display (`order_placed`, `confirmed`, `in_progress`, `in_transit`, `completed`, `cancelled`)
- **Progress Tracking**: Percentage-based progress bar (0%, 25%, 50%, 85%, 100%)
- **Service-Specific Messaging**: Same customer status, different display messages per service type

---

## Route & Task Management

### **Route Creation & Optimization**

- **Creation Methods**: Both manual (dispatchers create routes) and automatic (system generates routes)
- **Assignment**: Dispatchers assign routes to individual riders or rider groups
- **Route Size**: Maximum 40 stops per route
- **Optimization Scope**: Only applies to pickup/delivery service type
- **Re-optimization Triggers**:
  - Route modifications (add/remove stops)
  - Rider deviates from sequence
  - Emergency order insertion
  - Failed delivery stops

### **Optimization Configuration**

- **Approach**: Tenant-specific, UI-configurable optimization factors
- **Factors**: Distance weight, time weight, rider efficiency weight, customer time window weight, capacity utilization weight
- **Algorithm Support**: Multiple algorithms per tenant (Google Maps, custom algorithms)
- **A/B Testing**: Support for algorithm comparison and performance measurement

### **Rider Capacity & Scheduling**

- **Capacity Model**: Number of orders (default 40 max deliveries per rider)
- **Future Support**: Volume (liters) and weight (kg) constraints planned
- **Work Schedules**: Weekly schedule with shift limits, break duration tracking
- **Efficiency Scoring**: Rider efficiency factor for optimization (1.0 = average, 1.5 = 50% better)

### **Route Execution & Overrides**

- **Sequence Flexibility**: Riders should follow optimized sequence but can override
- **Override Behavior**: When rider completes wrong stop, route re-optimizes automatically
- **Failed Deliveries**: Riders tag stops as failed, no automatic retry
- **Emergency Insertion**: High-priority orders can interrupt existing routes
- **Route Assignment**: Riders can reject routes, system reassigns or returns to dispatcher

---

## User Management & Roles

### **User Roles & Permissions**

- **Admin**: Full tenant access across all hubs, configuration management
- **Dispatcher**: Hub-specific order and rider management, limited configuration
- **Rider**: Own profile and assigned orders only, location tracking permissions
- **Customer**: Own order history and profile, address management, rating submission

### **Rider Management**

- **Hub Assignment**: Riders belong to single hub, cannot work across hubs
- **Rider Groups**: Simple organizational grouping (one group per rider)
- **Vehicle Types**: Motorcycle, car, van, bicycle
- **Status Types**: Offline, available, busy, break
- **Rating System**: Customer rates riders (1-5 scale), affects assignment algorithm

### **Customer Management**

- **Account Scope**: Separate customer accounts per tenant
- **Address Sharing**: Delivery addresses shared across service types within tenant
- **Payment Methods**: COD, GCash, card processing
- **Order History**: Complete order history and transaction tracking

---

## Location & Geographic Features

### **Delivery Zones**

- **Zone Type**: Polygon-based boundaries drawn by admins
- **Overlap Handling**: Allowed with priority-based resolution
- **Assignment Logic**:
  1. Find all zones containing customer location
  2. Select hub with highest priority (1=highest)
  3. If equal priority, select hub with available riders
  4. If no riders available, wait until riders become available

### **Location Tracking & Route Analytics**

- **Tracking Scope**: Only active riders (offline riders don't send location)
- **Data Storage**: Start/end points + streets taken for analytics
- **Customer Sharing**: Real-time route sharing with customers
- **Route Compression**: Store as compressed linestring, capture points every 2 minutes
- **Street Names**: Actual streets taken stored for analytics and proof of delivery

### **Geographic Expansion Support**

- **Multi-country**: Timezone handling, local settings (currency, date formats)
- **Address Format**: Pin-based locations (not dependent on address formats)
- **Distance Calculations**: Account for local geography (islands, mountains)

---

## Financial & Payment System

### **Payment Methods**

- **Supported**: COD (Cash on Delivery), GCash, card processing
- **Payment Consistency**: Orders cannot change payment method after creation
- **COD Tracking**: Separate collection records for cash handling and reconciliation
- **Tokenization**: Payment card data tokenized through gateways

### **Pricing & Financial Rules**

- **COD Security**: Amount management left to rider discretion
- **Audit Trails**: Complete financial transaction logging required
- **Payment Status**: Tracks completion, not method changes
- **Failed Payments**: Handled by retry/refund process, no automatic COD conversion

---

## Integration & External Services

### **Mapping Services**

- **Primary**: Google Maps and Mapbox (both supported as options/fallback)
- **Offline Maps**: Maybe (evaluate based on connectivity issues)
- **Route Optimization**: Integration with Google Maps/Mapbox APIs
- **Real-time Traffic**: Historical traffic patterns not priority initially

### **Communication Services**

- **SMS Provider**: To be determined for Philippines market
- **Push Notifications**: Standard push notification implementation
- **Real-time Updates**: Socket.io for new orders, status updates, rider locations

### **Future Integrations**

- **POS Systems**: Not planned initially
- **Identity Verification**: Not specified
- **Analytics Tools**: Not specified
- **Payment Gateways**: Standardized globally for now

---

## Performance & Optimization

### **Response Time Targets**

- **Order placement/confirmation**: 10 seconds
- **Rider assignment (manual)**: 10 seconds
- **Rider assignment (auto)**: 20 seconds
- **Real-time location updates**: 30 seconds
- **Route optimization calculation**: 60 seconds

### **Indexing Strategy**

**Priority**: Admin dashboard and customer tracking queries

- **Multi-tenant isolation**: `tenant_id`, `hub_id` combinations
- **Order management**: Status-based queries, customer tracking
- **Location queries**: Spatial indexes for geographic operations
- **Sync queue**: Priority-based processing optimization

### **Scalability Approach**

- **Connection Pooling**: Support for 31K concurrent connections
- **Read Replicas**: AWS managed for analytics queries
- **Caching**: Redis for frequently accessed data
- **Partitioning**: Deferred until data volume requires it

---

## Security & Compliance

### **Authentication & Authorization**

- **Authentication Method**: JWT tokens (implementation details TBD)
- **Session Management**: Infinite persistence for riders, standard for others
- **Multi-factor Authentication**: Not required initially
- **Row Level Security**: Tenant isolation enforced at database level

### **Data Protection & Privacy**

- **Location Data Retention**: 7 days automatic cleanup
- **Customer Location Visibility**: Exact rider location visible to customers
- **Data Anonymization**: None required initially
- **Compliance**: Philippine Data Privacy Act compliance not required for MVP

### **Audit & Financial Security**

- **Financial Audit Trails**: Complete transaction logging required
- **Payment Tokenization**: Through gateway providers
- **COD Security**: Rider-managed amounts
- **Cross-tenant Isolation**: Standard row-level security, no additional encryption

---

## Implementation Priorities

### **Critical Issues Resolved**

1. **Hub Transfer Design**: Multi-hop support with sequence tracking
2. **Service Data Validation**: Hybrid columns + JSONB approach
3. **Pricing Complexity**: Simplified to flat rate vs base+distance
4. **Payment Consistency**: Database constraints preventing mismatches
5. **Zone Overlap Resolution**: Priority-based assignment rules
6. **Location Data Volume**: Redis + PostgreSQL hybrid approach
7. **Sync Queue Management**: Priority-based with retry limits
8. **Route Override Support**: Manual overrides with re-optimization

### **Development Timeline (1 Month)**

**Week 1-2**: PostgreSQL implementation, API integration architecture
**Week 3-4**: Core business logic, route optimization integration
**Post-Launch**: Advanced analytics, machine learning optimization, comprehensive documentation

### **Infrastructure Decisions**

- **Cloud Provider**: AWS (RDS, Redis, S3, CloudWatch)
- **Environments**: Development, staging, production databases
- **Backup Strategy**: Monthly backups (as specified), daily incremental recommended
- **Monitoring**: AWS managed services, custom alerts for critical metrics
- **Disaster Recovery**: AWS managed solutions

### **Order Details Service-Specific Fields**

We established hybrid approach with these specific fields per service type:

**Food Service Fields:**

- `restaurant_id` (UUID) - Reference to restaurant/merchant
- `estimated_prep_time` (INTEGER) - Food preparation time in minutes

**Transport Service Fields:**

- `vehicle_type` (VARCHAR) - Required vehicle type (bike, car, MPV, van)
- `passenger_count` (INTEGER) - Number of passengers

**Shopping Service Fields:**

- `store_name` (VARCHAR) - Store/merchant name
- `budget_limit` (DECIMAL) - Maximum spending limit

**Errands Service Fields:**

- `task_type` (VARCHAR) - Type of errand (bill_payment, document_submission, etc.)
- `deadline` (TIMESTAMPTZ) - Task completion deadline

**Pickup/Delivery Service Fields:**

- `package_type` (VARCHAR) - Type of package/item
- `weight_kg` (DECIMAL) - Package weight
- `is_fragile` (BOOLEAN) - Fragile handling flag

### **Reference Number Generation**

- **Current Decision**: Deferred implementation details
- **Requirement**: `reference_number` field exists but generation strategy undefined
- **Format**: To be determined (tenant-specific vs global, numeric vs alphanumeric)

### **Product Availability Logic**

- **Manual Override Priority**: `products.is_available` takes precedence over schedule
- **Schedule Logic**: Time-based availability only applies when manual toggle is enabled
- **Validation Rule**: Manual disable overrides any schedule-based availability

### **Sync Queue Cleanup Strategy**

- **Successful Items**: Auto-delete after 24 hours
- **Failed Items**: Flag for manual review after max attempts reached
- **Cleanup Field**: `auto_cleanup_at` timestamp for automated cleanup
- **Manual Review**: `needs_manual_review` boolean flag

### **Hub Transfer Status Flow**

- **Hub Transfer Statuses**: `initiated`, `in_transit`, `arrived`, `completed`, `failed`
- **Order Status Integration**: Hub transfers map to order statuses `in_transit_to_hub`, `arrived_at_hub`
- **Sequence Tracking**: Each transfer has `transfer_sequence` number for multi-hop tracking

### **Route Assignment Workflow**

- **Assignment Types**: `individual` (specific rider) or `group` (rider group self-selection)
- **Status Flow**: `pending` → `accepted`/`rejected`
- **Rejection Handling**: Riders provide rejection reason, system can reassign
- **Group Assignment**: Multiple riders in group can see and accept route

### **Emergency Order Processing**

- **Priority Levels**: `emergency`, `high`, `normal`, `low`
- **Route Interruption**: `can_interrupt_routes` boolean flag
- **Capacity Override**: Emergency orders can exceed normal capacity limits
- **Assignment Priority**: Emergency orders get immediate retry (bypass exponential backoff)

### **Work Schedule Integration**

- **Schedule Structure**: Daily shifts with start/end times, max duration, break requirements
- **Route Duration**: Routes respect rider work schedule limits
- **Efficiency Factor**: Rider efficiency score affects optimization calculations
- **Capacity Tracking**: Current capacity usage vs maximum capacity

### **Location Accuracy Implementation**

- **Accuracy Threshold**: 50m minimum for delivery confirmations
- **Validation**: `meets_threshold` boolean in location accuracy logs
- **Rejection Handling**: No retry for inaccurate locations, accept or reject based on threshold
- **Tracking**: `location_accuracy_logs` table monitors GPS quality

### **Pricing Schedule Activation**

- **Time-based Pricing**: Custom time ranges with day-of-week specification
- **Multiplier Application**: Pricing schedules apply multiplier to base pricing rules
- **Active Schedule**: Only one pricing schedule active per time period
- **Hub-specific**: Pricing schedules are hub-specific, not tenant-wide

---

## Outstanding Technical Decisions

### **Immediate Implementation Needs**

1. **Order Status System**: Implement dual status approach (operational + customer)
2. **Authentication Method**: Finalize JWT implementation details
3. **Route Optimization APIs**: Define algorithm interfaces and data exchange formats
4. **Emergency Order Logic**: Implement priority-based route interruption
5. **Capacity Management**: Implement rider capacity tracking and enforcement
6. **Reference Number Generation**: Define generation strategy and format
7. **Real-time Location Processing**: Implement Redis + PostgreSQL hybrid processing
8. **Sync Queue Processing**: Implement priority-based queue processing with cleanup

### **Configuration Requirements**

1. **Optimization Factors**: UI configuration to algorithm parameter mapping
2. **Pricing Rules**: Time-based activation and factor combination logic
3. **Work Schedule Integration**: Automatic route duration limits and break scheduling
4. **Hub Transfer Coordination**: Timing and capacity management between hubs
5. **Zone Priority Resolution**: Implement hub selection logic for overlapping zones
6. **Emergency Order Policies**: Define capacity override rules and pricing premiums

### **Data Processing & Analytics**

1. **Route Performance Tracking**: Implement optimization improvement measurement
2. **Rider Performance Metrics**: Automated calculation of efficiency scores
3. **Location Data Compression**: Implement route polyline generation and street name capture
4. **Financial Reconciliation**: COD collection tracking and payment consistency validation

### **Integration Architecture**

1. **Algorithm Interface Design**: Standardized input/output for optimization algorithms
2. **Map Service Integration**: Google Maps and Mapbox API integration patterns
3. **Real-time Event Processing**: Socket.io event routing and delivery confirmation
4. **Mobile Sync Protocol**: Offline queue synchronization API design

### **Business Logic Implementation**

1. **Hub Transfer Orchestration**: Multi-hop transfer coordination and timing
2. **Route Re-optimization Triggers**: Automated re-optimization condition handling
3. **Capacity Overflow Management**: Handling when system reaches capacity limits
4. **Time Window Validation**: Customer delivery window conflict resolution

### **Future Enhancement Areas**

1. **Machine Learning**: Route optimization learning from historical performance
2. **Predictive Analytics**: Demand forecasting and capacity planning
3. **Advanced Capacity**: Volume and weight constraints for orders
4. **Multi-region Deployment**: Data replication and latency optimization
5. **Algorithm A/B Testing**: Framework for comparing optimization algorithms
6. **Customer Behavior Analytics**: Order pattern analysis and personalization

---

## Unresolved Design Areas Requiring Discussion

### **1. Real-time Data Synchronization**

**Status**: Architecture defined but implementation details missing
**Missing Elements**:

- Redis data structure design for location tracking
- Conflict resolution when Redis and PostgreSQL data diverge
- Network failure recovery protocols for real-time updates
- Data consistency guarantees between Redis cache and database

### **2. Route Optimization Algorithm Integration**

**Status**: Configuration framework designed but algorithm interfaces undefined
**Missing Elements**:

- Standardized input format for optimization algorithms
- Output format specification for route sequences
- Algorithm switching logic and rollback procedures
- Performance benchmarking and comparison metrics
- Error handling when optimization algorithms fail

### **3. Mobile App Sync Protocol Design**

**Status**: Queue structure defined but sync protocol specifics missing
**Missing Elements**:

- Batch sync vs individual item sync strategies
- Network optimization for low-bandwidth scenarios
- Partial sync recovery when sync is interrupted
- Version conflict resolution between mobile and server data
- Sync progress indication and error reporting to riders

### **4. Financial Transaction Reconciliation**

**Status**: Data model complete but reconciliation processes undefined
**Missing Elements**:

- COD collection reconciliation workflow
- Payment gateway webhook handling and retry logic
- Financial discrepancy detection and resolution procedures
- Multi-currency support for international expansion
- Tax calculation automation and regional compliance

### **5. Hub Transfer Coordination Logic**

**Status**: Data model supports transfers but coordination logic undefined
**Missing Elements**:

- Transfer request approval workflow between hubs
- Capacity validation at receiving hub before transfer
- Transfer failure handling and fallback procedures
- Cost allocation between hubs for transfers
- Transfer performance optimization (timing, routing)

### **6. Customer Communication Strategy**

**Status**: Status system designed but communication triggers undefined
**Missing Elements**:

- Automated notification trigger conditions
- Communication preference management (SMS, push, email)
- Delivery delay notification logic and escalation procedures
- Customer service integration for status override scenarios
- Multi-language notification template management

### **7. Analytics and Reporting Framework**

**Status**: Data collection planned but reporting structure undefined
**Missing Elements**:

- Real-time dashboard query optimization strategies
- Data aggregation and summarization procedures
- Performance metric calculation algorithms
- Business intelligence reporting structure
- Data export and integration capabilities for external analytics

### **8. System Integration Testing Strategy**

**Status**: Individual components designed but integration testing undefined
**Missing Elements**:

- End-to-end workflow testing scenarios
- Performance testing under realistic load conditions
- Disaster recovery testing and failover procedures
- Data migration testing for schema changes
- Security penetration testing for multi-tenant isolation

---

## Next Agent Handoff Instructions

This knowledge base contains all critical design decisions and requirements established during the database architecture discussion. The schema design is complete and addresses all identified flaws and requirements.

**PRIORITY 1 - Immediate Implementation (Week 1-2)**:

1. **Generate Complete PostgreSQL Schema**: Create all table creation scripts with constraints, indexes, and triggers
2. **Implement Dual Order Status System**: Build operational vs customer status mapping with automated triggers
3. **Design API Integration Architecture**: Define database access patterns for React Native app and admin dashboard
4. **Create Reference Number Generation**: Implement order reference number generation strategy

**PRIORITY 2 - Core Business Logic (Week 2-3)**:

1. **Route Optimization API Design**: Define algorithm interfaces, input/output formats, and switching logic
2. **Emergency Order Processing**: Implement priority-based route interruption and capacity override logic
3. **Hub Transfer Coordination**: Build multi-hop transfer workflow with timing and capacity validation
4. **Pricing Engine Implementation**: Build calculation engine for flat rate vs base+distance models

**PRIORITY 3 - Real-time & Sync (Week 3-4)**:

1. **Redis Location Tracking**: Implement hybrid Redis+PostgreSQL location processing
2. **Mobile Sync Protocol**: Design and implement priority-based offline sync with conflict resolution
3. **Real-time Event System**: Build Socket.io integration with database triggers
4. **Capacity Management**: Implement rider capacity tracking and route assignment logic

**UNRESOLVED AREAS REQUIRING IMMEDIATE ATTENTION**:

1. **Real-time Data Synchronization** - Redis structure and consistency protocols
2. **Route Optimization Integration** - Algorithm interfaces and error handling
3. **Mobile Sync Protocol** - Detailed sync workflow and conflict resolution
4. **Financial Reconciliation** - COD and payment gateway integration procedures
5. **Hub Transfer Logic** - Inter-hub coordination and approval workflows
6. **Customer Communication** - Notification triggers and preference management
7. **Analytics Framework** - Reporting structure and performance metrics
8. **Integration Testing** - End-to-end testing strategy and load testing

**Key files to reference**:

- Complete database schema design (airship_schema_design artifact)
- Task status tracking (airship_tasks artifact)
- This comprehensive knowledge base (airship_schema_knowledge.md)

**Critical success metrics**:

- Support 10K orders/day across 150 tenants
- Handle 450K location updates/hour efficiently
- Maintain <10 second response times for core operations
- Enable offline-first rider app with reliable sync
- Achieve 99%+ sync success rate for critical financial data

**IMPORTANT NOTE**: While the database schema is complete and production-ready, the eight unresolved design areas listed above require architectural decisions before full implementation. These areas involve complex business logic, real-time processing, and integration protocols that need detailed design work beyond the database layer.
