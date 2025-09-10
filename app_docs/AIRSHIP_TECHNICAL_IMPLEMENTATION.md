# Airship Lite - Technical Implementation

*For platform architecture and user workflows, see [AIRSHIP_PLATFORM_ARCHITECTURE.md](AIRSHIP_PLATFORM_ARCHITECTURE.md)*
*For development timeline and priorities, see [AIRSHIP_DEVELOPMENT_ROADMAP.md](AIRSHIP_DEVELOPMENT_ROADMAP.md)*

## Database Architecture & Design

### **Technology Stack**

#### **Primary Database: PostgreSQL 15+**
- **Multi-tenancy Support:** Row Level Security (RLS) for complete tenant isolation
- **Geospatial Capabilities:** PostGIS extension for delivery zones and location tracking
- **ACID Compliance:** Critical for financial data integrity and order consistency
- **JSON Support:** JSONB fields for flexible service-specific data storage
- **Cloud Deployment:** AWS RDS with managed services for scalability and maintenance

#### **Supporting Technologies**
- **Redis:** Real-time location tracking and session management
- **AWS S3:** Media storage for proof of delivery photos and documents
- **CloudWatch:** System monitoring and performance analytics
- **API Gateway:** Request routing and authentication management

### **Multi-Tenant Database Design**

#### **Tenant Isolation Strategy**
- **Approach:** Soft isolation using `tenant_id` in all tables
- **Row Level Security:** Database-enforced tenant separation with RLS policies
- **Scale Target:** Support 155 tenants in Year 1 with 20% monthly growth
- **Data Separation:** Complete isolation - no cross-tenant data access possible

#### **Core Tenant Structure**
```sql
-- Master tenant accounts
CREATE TABLE tenants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(100) UNIQUE NOT NULL,
    subscription_plan VARCHAR(50) DEFAULT 'basic',
    status VARCHAR(20) DEFAULT 'active',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Physical locations/branches per tenant
CREATE TABLE hubs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    location GEOGRAPHY(POINT, 4326),
    delivery_radius_km DECIMAL(8,2) DEFAULT 10.0,
    status VARCHAR(20) DEFAULT 'active'
);
```

#### **Hub-Based Operations**
- **Hub Isolation:** Strict separation - riders cannot work across hubs
- **Service Areas:** Polygon-based delivery zones with overlap handling
- **Zone Priority:** Priority-based hub selection for overlapping zones (1=highest)
- **Hub Transfers:** Multi-hop transfer support with sequence tracking

### **Service-Specific Data Architecture**

#### **Unified Orders Table**
Single `orders` table handles all service types with hybrid data approach:

```sql
CREATE TABLE orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    hub_id UUID NOT NULL REFERENCES hubs(id),
    service_type VARCHAR(50) NOT NULL CHECK (service_type IN ('pickup_delivery', 'food_delivery', 'shopping', 'errands', 'transportation')),
    
    -- Universal fields
    customer_id UUID REFERENCES customers(id),
    status VARCHAR(50) DEFAULT 'placed',
    total_amount DECIMAL(10,2),
    payment_method VARCHAR(50),
    
    -- Service-specific structured fields
    restaurant_id UUID, -- Food delivery
    estimated_prep_time INTEGER, -- Food delivery
    vehicle_type VARCHAR(50), -- Transportation
    passenger_count INTEGER, -- Transportation
    store_name VARCHAR(255), -- Shopping
    budget_limit DECIMAL(10,2), -- Shopping
    task_type VARCHAR(100), -- Errands
    deadline TIMESTAMPTZ, -- Errands
    package_type VARCHAR(100), -- Pickup/Delivery
    weight_kg DECIMAL(8,2), -- Pickup/Delivery
    is_fragile BOOLEAN, -- Pickup/Delivery
    
    -- Flexible JSONB for additional service data
    additional_data JSONB DEFAULT '{}',
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

#### **Hybrid Data Storage Strategy**
- **Structured Columns:** Critical queryable fields get dedicated columns
- **JSONB Storage:** Flexible data in `additional_data` field with schema versioning
- **Query Performance:** Indexed structured fields for fast filtering and reporting
- **Future Flexibility:** JSONB allows new service types without schema changes

### **User Management & Authentication**

#### **User Role Architecture**
```sql
-- Platform-level customers (separate from employees)
CREATE TABLE customers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(20),
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    password_hash VARCHAR(255),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Employee/admin accounts with tenant association
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    hub_id UUID REFERENCES hubs(id),
    email VARCHAR(255) UNIQUE NOT NULL,
    role VARCHAR(50) NOT NULL CHECK (role IN ('super_admin', 'hub_admin', 'dispatcher')),
    permissions JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Delivery personnel with detailed profiles
CREATE TABLE riders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    hub_id UUID NOT NULL REFERENCES hubs(id),
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(20) NOT NULL,
    vehicle_type VARCHAR(50),
    max_capacity INTEGER DEFAULT 40,
    efficiency_factor DECIMAL(3,2) DEFAULT 1.00,
    status VARCHAR(20) DEFAULT 'offline',
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

#### **Authentication & Session Management**
- **JWT Tokens:** Stateless authentication with configurable expiration
- **Infinite Persistence:** Rider sessions don't expire to prevent work interruption
- **Role-Based Access:** Permissions enforced at database level with RLS policies
- **Multi-Factor Authentication:** Planned for future implementation (not MVP)

### **Real-Time Location & Route Management**

#### **Hybrid Location Tracking**
**Redis Layer (Active Tracking):**
- **Purpose:** Real-time location updates for active riders
- **Frequency:** 30-45 second intervals during active delivery
- **Data Retention:** 1-hour automatic expiry
- **Volume:** 91,875 location updates/hour peak (1,150 riders × 80 updates/hour during active delivery)

**PostgreSQL Layer (Historical Data):**
```sql
CREATE TABLE rider_locations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    rider_id UUID NOT NULL REFERENCES riders(id),
    location GEOGRAPHY(POINT, 4326) NOT NULL,
    accuracy_meters DECIMAL(8,2),
    recorded_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Compressed route storage for analytics
CREATE TABLE route_summaries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    route_id UUID NOT NULL REFERENCES routes(id),
    path_linestring GEOGRAPHY(LINESTRING, 4326),
    total_distance_km DECIMAL(10,3),
    total_duration_minutes INTEGER,
    streets_taken TEXT[],
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

**Location Data Management:**
- **Accuracy Threshold:** 50m minimum for delivery confirmations
- **Data Retention:** 7 days for detailed location data, permanent for route summaries
- **Street Tracking:** Actual streets taken stored for analytics and proof
- **Customer Sharing:** Real-time route sharing with customers during delivery

### **Route Optimization & Management**

#### **Route Data Structure**
```sql
CREATE TABLE routes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    hub_id UUID NOT NULL REFERENCES hubs(id),
    name VARCHAR(255),
    total_stops INTEGER,
    estimated_duration_minutes INTEGER,
    total_distance_km DECIMAL(10,3),
    optimization_algorithm VARCHAR(100),
    status VARCHAR(50) DEFAULT 'draft',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE route_stops (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    route_id UUID NOT NULL REFERENCES routes(id),
    order_id UUID NOT NULL REFERENCES orders(id),
    stop_sequence INTEGER NOT NULL,
    stop_type VARCHAR(20) CHECK (stop_type IN ('pickup', 'delivery')),
    location GEOGRAPHY(POINT, 4326) NOT NULL,
    estimated_arrival TIMESTAMPTZ,
    actual_arrival TIMESTAMPTZ,
    completed_at TIMESTAMPTZ
);
```

#### **Optimization Configuration**
```sql
CREATE TABLE optimization_configurations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    hub_id UUID REFERENCES hubs(id),
    algorithm_name VARCHAR(100) NOT NULL,
    distance_weight DECIMAL(3,2) DEFAULT 1.00,
    time_weight DECIMAL(3,2) DEFAULT 1.00,
    rider_efficiency_weight DECIMAL(3,2) DEFAULT 1.00,
    customer_window_weight DECIMAL(3,2) DEFAULT 1.00,
    capacity_weight DECIMAL(3,2) DEFAULT 1.00,
    is_active BOOLEAN DEFAULT false
);
```

#### **Route Management Features**
- **Maximum Route Size:** 40 stops per route
- **Re-optimization Triggers:** Route modifications, rider deviations, emergency insertions
- **Algorithm Support:** Multiple optimization algorithms per tenant
- **A/B Testing:** Algorithm comparison and performance measurement
- **Override Capability:** Riders can deviate with automatic re-optimization

### **Pricing & Financial Management**

#### **Simplified Pricing System**
```sql
CREATE TABLE pricing_rules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    hub_id UUID REFERENCES hubs(id),
    service_type VARCHAR(50) NOT NULL,
    pricing_type VARCHAR(20) CHECK (pricing_type IN ('flat_rate', 'base_plus_distance')),
    base_fee DECIMAL(8,2) NOT NULL,
    per_km_rate DECIMAL(8,2),
    is_active BOOLEAN DEFAULT true
);

CREATE TABLE pricing_schedules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    hub_id UUID NOT NULL REFERENCES hubs(id),
    name VARCHAR(255) NOT NULL,
    day_of_week INTEGER[], -- 0=Sunday, 6=Saturday
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    multiplier DECIMAL(4,2) DEFAULT 1.00,
    is_active BOOLEAN DEFAULT true
);
```

#### **Financial Transaction Management**
```sql
CREATE TABLE order_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID NOT NULL REFERENCES orders(id),
    transaction_type VARCHAR(50) NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    payment_method VARCHAR(50),
    gateway_transaction_id VARCHAR(255),
    status VARCHAR(50) DEFAULT 'pending',
    processed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- COD collection tracking
CREATE TABLE cash_collections (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    rider_id UUID NOT NULL REFERENCES riders(id),
    order_id UUID NOT NULL REFERENCES orders(id),
    amount_collected DECIMAL(10,2),
    collection_time TIMESTAMPTZ DEFAULT NOW(),
    reconciled BOOLEAN DEFAULT false
);
```

#### **Payment Processing Rules**
- **Payment Consistency:** Orders cannot change payment method after creation
- **COD Management:** Rider discretion for amount handling
- **Audit Trails:** Complete financial transaction logging required
- **Gateway Integration:** Tokenized payment processing through external providers

### **Mobile App Sync Architecture**

#### **Offline-First Mobile Design**
**Mobile Technology Stack:**
- **Framework:** React Native + TypeScript
- **State Management:** Zustand for predictable state management
- **Local Database:** SQLite for offline sync queue and data persistence
- **Network Layer:** Axios with retry interceptors and request/response caching

```sql
CREATE TABLE sync_queue (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    rider_id UUID NOT NULL REFERENCES riders(id),
    operation_type VARCHAR(100) NOT NULL,
    priority_level INTEGER NOT NULL,
    data JSONB NOT NULL,
    max_attempts INTEGER,
    current_attempts INTEGER DEFAULT 0,
    last_attempt_at TIMESTAMPTZ,
    needs_manual_review BOOLEAN DEFAULT false,
    auto_cleanup_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

#### **Priority-Based Sync System**
**Priority Levels:**
1. **Critical Financial (Priority 1):** COD payments, transaction confirmations - 100 max attempts
2. **Task Completion (Priority 2):** Delivery confirmations, status updates - 50 max attempts  
3. **Status Updates (Priority 3):** Order status changes, location updates - 50 max attempts
4. **Media Uploads (Priority 4):** Photos, documents, proof files - 20 max attempts
5. **Location Data (Priority 5):** GPS tracking data - 20 max attempts

#### **Sync Management Features**
- **Atomic Operations:** Task completion + photo upload must both succeed
- **Intelligent Retry:** Exponential backoff with priority-based retry limits
- **Conflict Resolution:** Version control with server-side conflict resolution
- **Cleanup Strategy:** Auto-delete successful items after 24 hours
- **Manual Review:** Flag failed items after max attempts for manual intervention

### **Infrastructure Scaling & Provincial Market Adaptations**

#### **Infrastructure Scaling Checkpoints**
**Phased Scaling Strategy:**
- **3,000 orders/day:** Single-instance architecture ($400-500/month)
- **5,500 orders/day:** Upgraded database specs ($500-700/month) 
- **6,000 orders/day:** Read replicas + load balancing ($800-1,000/month)
- **10,000 orders/day:** Horizontal scaling + clustering ($1,500-2,000/month)

**Peak Load Management:**
- **Primary peaks:** 11am-1pm and 5pm-7pm requiring peak database capacity
- **Weather scaling:** Infrastructure must handle 2-3x normal capacity during extreme weather (typhoons/rain seasons)
- **Holiday adjustments:** Flexible auto-scaling capabilities for variable demand patterns

#### **Provincial Market Optimizations**
**Connectivity Adaptations:**
- **Offline-first architecture:** Extended sync tolerance for unreliable provincial connectivity
- **Priority-based sync queue:** Financial (100 attempts) > Task completion (50) > Status (50) > Media (20) > Location (20)
- **Local CDN nodes:** Bandwidth optimization for cost-effective service delivery

**Payment Processing Adaptations:**
- **COD support:** 70-80% COD in provincial markets vs 50% in Metro Manila
- **Cash collection tracking:** Robust reconciliation workflows for high COD usage
- **Payment method distribution:** Adapted for provincial payment preferences

**Customer Behavior Optimizations:**
- **Conservative tracking frequency:** Provincial customers track 25% less frequently than Metro Manila
- **Food delivery:** 4-6 tracking sessions per order (vs 8-12 in Metro Manila)
- **Pickup & delivery:** 2-3 sessions per order
- **Shopping:** 1-2 sessions per order
- **Session duration:** 1-2 minutes average (shorter attention spans)

### **Performance & Scalability Requirements**

#### **Response Time Targets (Provincial-Optimized)**
- **Order placement/confirmation:** 10 seconds maximum
- **Rider assignment (manual):** 10 seconds maximum  
- **Rider assignment (auto):** 20 seconds maximum
- **Real-time location updates:** 30 seconds maximum (adaptive frequency)
- **Route optimization calculation:** 60 seconds maximum

#### **Volume Capacity Targets**
- **Total Orders:** 10,000 orders/day across ALL tenants
- **Per Tenant Average:** ~65 orders/day per tenant (155 tenants)
- **Peak Processing:** 1,000 orders/hour system-wide
- **Location Updates:** 875K location updates/day, 91,875 peak updates/hour (realistic provincial usage patterns)  
- **Concurrent Connections:** 2,475 Socket.io connections at 10K orders/day (realistic provincial usage patterns)

#### **Database Indexing Strategy**

**Multi-tenant Performance:**
```sql
-- Tenant isolation indexes
CREATE INDEX idx_orders_tenant_id ON orders(tenant_id);
CREATE INDEX idx_orders_hub_id ON orders(hub_id);
CREATE INDEX idx_orders_tenant_hub ON orders(tenant_id, hub_id);

-- Order management indexes
CREATE INDEX idx_orders_status_created ON orders(status, created_at);
CREATE INDEX idx_orders_service_type ON orders(service_type);
CREATE INDEX idx_orders_customer_tracking ON orders(customer_id, status);

-- Location query optimization
CREATE INDEX idx_rider_locations_spatial ON rider_locations USING GIST(location);
CREATE INDEX idx_delivery_zones_spatial ON hub_delivery_zones USING GIST(zone_boundary);

-- Route optimization indexes
CREATE INDEX idx_route_stops_sequence ON route_stops(route_id, stop_sequence);
CREATE INDEX idx_routes_hub_status ON routes(hub_id, status);

-- Sync queue performance
CREATE INDEX idx_sync_queue_priority ON sync_queue(priority_level, created_at);
CREATE INDEX idx_sync_queue_rider ON sync_queue(rider_id, needs_manual_review);
```

### **Security & Data Protection**

#### **Row Level Security Implementation**
```sql
-- Enable RLS on all tenant-scoped tables
ALTER TABLE tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE riders ENABLE ROW LEVEL SECURITY;

-- Tenant isolation policies
CREATE POLICY tenant_isolation_orders ON orders
    FOR ALL USING (tenant_id = current_setting('app.current_tenant_id')::UUID);

CREATE POLICY tenant_isolation_users ON users
    FOR ALL USING (tenant_id = current_setting('app.current_tenant_id')::UUID);

CREATE POLICY tenant_isolation_riders ON riders
    FOR ALL USING (tenant_id = current_setting('app.current_tenant_id')::UUID);
```

#### **Data Protection Strategy**
- **Location Data Retention:** 7-day automatic cleanup for privacy compliance
- **Payment Tokenization:** Card data tokenized through gateway providers
- **Cross-Tenant Prevention:** RLS policies prevent data leakage
- **Audit Logging:** Complete transaction and access logging
- **Encryption:** Database encryption at rest and in transit

### **Infrastructure & Cloud Architecture**

#### **AWS Cloud Services**
- **RDS PostgreSQL:** Multi-AZ deployment with automated backups
- **ElastiCache Redis:** High-availability cluster for real-time data
- **S3:** Media storage with lifecycle policies for cost optimization
- **CloudWatch:** Comprehensive monitoring and alerting
- **Application Load Balancer:** High availability and SSL termination
- **API Gateway:** Request routing, throttling, and authentication

#### **Backup & Disaster Recovery**
- **Database Backups:** Daily automated backups with 30-day retention
- **Point-in-Time Recovery:** Up to 35 days for PostgreSQL
- **Cross-Region Replication:** Read replicas for disaster recovery
- **Media Backup:** S3 cross-region replication for critical files

#### **Monitoring & Observability**
```sql
-- Performance monitoring views
CREATE VIEW order_performance_metrics AS
SELECT 
    DATE_TRUNC('hour', created_at) as hour,
    service_type,
    COUNT(*) as order_count,
    AVG(EXTRACT(EPOCH FROM (updated_at - created_at))/60) as avg_completion_minutes
FROM orders 
WHERE status = 'completed'
GROUP BY DATE_TRUNC('hour', created_at), service_type;

-- Real-time system health
CREATE VIEW system_health_check AS
SELECT
    'orders' as table_name,
    COUNT(*) as record_count,
    MAX(created_at) as latest_record
FROM orders
UNION ALL
SELECT
    'rider_locations' as table_name,
    COUNT(*) as record_count,
    MAX(recorded_at) as latest_record
FROM rider_locations;
```

#### **Scalability Approach**
- **Connection Pooling:** pgBouncer for database connection management
- **Read Replicas:** Separate analytics queries from operational load
- **Horizontal Scaling:** Microservices architecture preparation
- **Caching Strategy:** Redis for frequently accessed data
- **API Rate Limiting:** Prevent abuse and ensure fair resource usage

### **Location Accuracy & GPS Quality Management**

#### **Accuracy Threshold Implementation**
```sql
CREATE TABLE location_accuracy_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    rider_id UUID NOT NULL REFERENCES riders(id),
    location GEOGRAPHY(POINT, 4326) NOT NULL,
    accuracy_meters DECIMAL(8,2) NOT NULL,
    meets_threshold BOOLEAN GENERATED ALWAYS AS (accuracy_meters <= 50.0) STORED,
    gps_quality VARCHAR(20) CHECK (gps_quality IN ('excellent', 'good', 'fair', 'poor')),
    recorded_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for accuracy monitoring
CREATE INDEX idx_location_accuracy_threshold ON location_accuracy_logs(meets_threshold, recorded_at);
```

#### **GPS Quality Standards**
- **Accuracy Threshold:** 50m minimum for delivery confirmations
- **Quality Assessment:** Real-time GPS signal quality monitoring
- **Rejection Policy:** No automatic retry for inaccurate locations - accept or reject based on threshold
- **Quality Logging:** Complete GPS accuracy tracking for performance analytics

### **Emergency Order Processing System**

#### **Priority-Based Order Management**
```sql
-- Enhanced orders table with emergency flags
ALTER TABLE orders ADD COLUMN priority VARCHAR(20) DEFAULT 'normal' 
    CHECK (priority IN ('emergency', 'high', 'normal', 'low'));
ALTER TABLE orders ADD COLUMN can_interrupt_routes BOOLEAN DEFAULT false;
ALTER TABLE orders ADD COLUMN capacity_override BOOLEAN DEFAULT false;

-- Emergency order processing function
CREATE OR REPLACE FUNCTION process_emergency_order(
    order_id UUID,
    interrupt_existing_routes BOOLEAN DEFAULT true
) RETURNS TABLE(
    affected_routes UUID[],
    reassignment_required BOOLEAN,
    estimated_impact_minutes INTEGER
) AS $$
DECLARE
    order_location GEOGRAPHY;
    affected_route_ids UUID[];
BEGIN
    -- Get emergency order location
    SELECT pickup_location INTO order_location FROM orders WHERE id = order_id;
    
    -- Mark order with emergency priority
    UPDATE orders SET 
        priority = 'emergency',
        can_interrupt_routes = interrupt_existing_routes,
        capacity_override = true
    WHERE id = order_id;
    
    -- Find affected routes within 5km radius if interruption allowed
    IF interrupt_existing_routes THEN
        SELECT ARRAY_AGG(r.id) INTO affected_route_ids
        FROM routes r
        JOIN route_assignments ra ON r.id = ra.route_id
        JOIN route_stops rs ON r.id = rs.route_id
        WHERE ra.status = 'in_progress'
        AND ST_Distance(rs.location, order_location) < 5000;
        
        RETURN QUERY SELECT 
            affected_route_ids,
            true,
            COALESCE(array_length(affected_route_ids, 1) * 15, 0); -- Estimated 15min impact per affected route
    ELSE
        RETURN QUERY SELECT 
            NULL::UUID[],
            false,
            0;
    END IF;
END;
$$ LANGUAGE plpgsql;
```

#### **Emergency Order Features**
- **Route Interruption:** `can_interrupt_routes` boolean flag enables mid-route insertion
- **Capacity Override:** Emergency orders can exceed normal rider capacity limits
- **Immediate Assignment:** Emergency orders bypass exponential backoff in assignment queue
- **Impact Assessment:** Automatic calculation of route disruption and estimated delays

---

## Outstanding Technical Decisions & Unresolved Design Areas

### **1. Real-Time Data Synchronization Architecture**

**Status:** Architecture framework defined, implementation details require resolution
**Critical Missing Elements:**

#### **Optimized Redis Data Structure Design**
```javascript
// Hybrid Redis + PostgreSQL with performance optimizations
rider:location:{rider_id} = {
  "batch": [
    {
      "lat": 14.5995,
      "lng": 120.9842,
      "accuracy": 15.5,
      "timestamp": "2024-01-01T12:00:00Z",
      "speed": 25.5
    },
    // 2-4 more points batched together
  ],
  "geofence_status": "moving", // stationary, moving, at_destination
  "last_movement": "2024-01-01T12:00:00Z",
  "adaptive_frequency": "active_delivery" // idle, active_delivery, at_stops
}

// Route progress with compression
route:progress:{route_id} = {
  "current_stop": 3,
  "completed_stops": [1, 2],
  "polyline_route": "u{~vFvyys@fS]", // Google Maps polyline format
  "estimated_completion": "2024-01-01T15:30:00Z",
  "rider_deviation": false
}
```

**Performance Optimizations:**
- **Adaptive Frequency:** Idle (2-3 min), Active delivery (30 sec), At stops (10 sec)
- **Geofencing:** Stop updates when riders stationary (50m threshold, 100m movement trigger)
- **Batching Strategy:** Group 3-5 location points per API call reducing database writes by 70-80%
- **Route Compression:** Google Maps polyline format achieves 90% storage reduction vs individual GPS points
- **Tiered Caching:** Hot (Redis), Warm (Redis), Cold (PostgreSQL) with 1-hour TTL for active riders

### **2. Route Optimization Algorithm Integration**

**Status:** Configuration framework designed, algorithm interfaces undefined
**Critical Missing Elements:**

#### **Algorithm Interface Standardization**
```javascript
// Standardized input format for optimization algorithms
{
  "optimization_request": {
    "tenant_id": "uuid",
    "hub_id": "uuid", 
    "algorithm_preference": "google_maps|custom_genetic|or_tools",
    "orders": [...],
    "rider_constraints": {...},
    "optimization_weights": {...}
  }
}

// Output format specification
{
  "optimization_result": {
    "route_id": "uuid",
    "algorithm_used": "google_maps_optimization",
    "quality_score": 0.85,
    "total_distance_km": 25.5,
    "estimated_duration_minutes": 180,
    "optimized_sequence": [...],
    "fallback_used": false,
    "processing_time_ms": 2500
  }
}
```

**Unresolved Issues:**
- **Algorithm Switching Logic:** Criteria for algorithm selection and rollback procedures
- **Performance Benchmarking:** Standardized metrics for algorithm comparison
- **Error Handling:** Fallback strategies when optimization algorithms fail
- **Real-Time Integration:** API response time guarantees and timeout handling

### **3. Mobile App Sync Protocol Design**

**Status:** Queue structure defined, sync protocol specifics missing
**Critical Missing Elements:**

#### **Sync Strategy Decision Matrix**
```javascript
// Sync strategy based on data type and network conditions
const syncStrategies = {
  "critical_financial": {
    "strategy": "individual_immediate",
    "max_attempts": 100,
    "retry_interval": "exponential_backoff",
    "conflict_resolution": "server_wins"
  },
  "task_completion": {
    "strategy": "batch_prioritized", 
    "batch_size": 5,
    "max_attempts": 50,
    "conflict_resolution": "timestamp_wins"
  },
  "location_data": {
    "strategy": "batch_compressed",
    "batch_size": 20,
    "max_attempts": 20,
    "conflict_resolution": "latest_wins"
  }
};
```

**Unresolved Issues:**
- **Batch vs Individual Sync:** Decision criteria for sync strategy selection
- **Network Optimization:** Low-bandwidth scenario handling and compression strategies
- **Partial Sync Recovery:** Resuming interrupted sync operations with state preservation
- **Version Conflict Resolution:** Mobile vs server data conflict resolution protocols
- **Progress Indication:** User feedback during sync operations and error reporting

### **4. Financial Transaction Reconciliation**

**Status:** Data model complete, reconciliation processes undefined
**Critical Missing Elements:**

#### **COD Collection Reconciliation Workflow**
```sql
-- COD reconciliation process
CREATE OR REPLACE FUNCTION reconcile_cod_collections(
    rider_id UUID,
    reconciliation_date DATE
) RETURNS TABLE(
    total_collected DECIMAL(10,2),
    total_expected DECIMAL(10,2),
    discrepancy DECIMAL(10,2),
    unreconciled_orders UUID[]
) AS $$
BEGIN
    -- Implementation needed for:
    -- 1. Daily COD collection totals
    -- 2. Expected vs actual collection comparison
    -- 3. Discrepancy identification and flagging
    -- 4. Automated reconciliation reporting
END;
$$ LANGUAGE plpgsql;
```

**Unresolved Issues:**
- **Payment Gateway Webhooks:** Webhook handling, retry logic, and failure recovery
- **Discrepancy Detection:** Automated identification and resolution procedures
- **Multi-Currency Support:** International expansion currency handling
- **Tax Calculation:** Regional compliance and automated tax calculation

### **5. Hub Transfer Coordination Logic**

**Status:** Data model supports transfers, coordination logic undefined
**Critical Missing Elements:**

**Unresolved Issues:**
- **Transfer Request Approval:** Workflow between hubs for transfer authorization
- **Capacity Validation:** Real-time capacity checking at receiving hub before transfer
- **Transfer Failure Handling:** Fallback procedures and alternative routing
- **Cost Allocation:** Hub-to-hub transfer cost calculation and billing
- **Transfer Optimization:** Timing and routing optimization for multi-hop transfers

### **6. Customer Communication Strategy**

**Status:** Status system designed, communication triggers undefined
**Critical Missing Elements:**

**Unresolved Issues:**
- **Notification Triggers:** Automated conditions for customer communications
- **Communication Preferences:** SMS, push, email preference management per customer
- **Delay Notifications:** Logic and escalation procedures for delivery delays
- **Customer Service Integration:** Status override scenarios and manual intervention
- **Multi-Language Templates:** Notification template management for international markets

### **7. Analytics and Reporting Framework**

**Status:** Data collection planned, reporting structure undefined
**Critical Missing Elements:**

**Unresolved Issues:**
- **Real-Time Dashboard Optimization:** Query optimization for live operational dashboards
- **Data Aggregation Procedures:** Automated summarization and metric calculation
- **Performance Metrics Algorithms:** Business intelligence calculation methods
- **Business Intelligence Structure:** Reporting hierarchy and data access patterns
- **External Analytics Integration:** Data export and integration capabilities

### **8. System Integration Testing Strategy**

**Status:** Individual components designed, integration testing undefined
**Critical Missing Elements:**

**Unresolved Issues:**
- **End-to-End Workflow Testing:** Complete order lifecycle testing scenarios
- **Performance Testing:** Realistic load conditions and capacity validation
- **Disaster Recovery Testing:** Failover procedures and system recovery validation
- **Data Migration Testing:** Schema changes and backwards compatibility
- **Security Testing:** Multi-tenant isolation and penetration testing procedures

---

## Future Enhancement Areas

### **1. Machine Learning & AI Integration**
- **Route Optimization Learning:** Historical performance data to improve algorithm accuracy
- **Demand Forecasting:** Predictive analytics for capacity planning and resource allocation
- **Dynamic Pricing:** ML-driven surge pricing based on demand patterns and supply availability
- **Rider Performance Prediction:** AI-powered efficiency scoring and assignment optimization

### **2. Advanced Analytics & Intelligence**
- **Customer Behavior Analysis:** Order pattern analysis and personalized service recommendations
- **Predictive Maintenance:** System performance monitoring and proactive issue resolution
- **Business Intelligence Automation:** Automated insights and recommendation generation
- **Real-Time Decision Support:** AI-powered operational decision assistance

### **3. Enhanced Capacity Management**
- **Volume and Weight Constraints:** Advanced capacity calculations beyond order count
- **Multi-Modal Transportation:** Integration of different vehicle types and capacity optimization
- **Dynamic Capacity Scaling:** Real-time capacity adjustment based on demand patterns
- **Predictive Capacity Planning:** Forecast-based rider scheduling and resource allocation

### **4. Multi-Region Deployment**
- **Data Replication Strategy:** Cross-region data synchronization and consistency
- **Latency Optimization:** Geographic distribution and edge computing integration
- **Localization Framework:** Cultural and regulatory adaptation for different markets
- **Currency and Tax Automation:** Multi-currency support with automated compliance

### **5. Algorithm A/B Testing Framework**
- **Performance Comparison:** Standardized benchmarking across optimization algorithms
- **Gradual Rollout:** Controlled algorithm deployment and performance monitoring
- **Business Impact Analysis:** Revenue and efficiency impact measurement
- **Automated Algorithm Selection:** AI-driven algorithm selection based on performance metrics

### **6. Advanced Integration Capabilities**
- **POS System Integration:** Direct connection with merchant point-of-sale systems
- **ERP Integration:** Enterprise resource planning system connectivity
- **Third-Party Logistics:** Integration with external delivery service providers
- **IoT Device Integration:** Smart sensors for vehicle tracking and condition monitoring

This comprehensive technical implementation provides the foundation for building a scalable, reliable, and performant multi-tenant delivery management platform while identifying critical areas requiring immediate architectural decisions before full production deployment.