# Airship Lite - Development Roadmap

*For platform architecture details, see [AIRSHIP_PLATFORM_ARCHITECTURE.md](AIRSHIP_PLATFORM_ARCHITECTURE.md)*
*For technical implementation specifics, see [AIRSHIP_TECHNICAL_IMPLEMENTATION.md](AIRSHIP_TECHNICAL_IMPLEMENTATION.md)*
*For business context and requirements, see [AIRSHIP_BUSINESS_OVERVIEW.md](AIRSHIP_BUSINESS_OVERVIEW.md)*

## Implementation Timeline Overview

### **Development Phase: 1 Month Complete Implementation**

**Target:** Production-ready multi-tenant delivery management platform supporting 10,000 orders/day across 150 tenants with full offline mobile capabilities and real-time optimization.

#### **Week 1-2: Database Foundation & Core Architecture**
- Complete PostgreSQL schema implementation with multi-tenant isolation
- Row Level Security (RLS) policies and tenant separation
- API integration architecture design
- Basic authentication and user management

#### **Week 3-4: Business Logic & Real-Time Systems**
- Route optimization integration and algorithm interfaces  
- Emergency order processing and priority systems
- Mobile sync protocol and offline queue management
- Real-time location tracking with Redis integration

**Post-Launch: Enhancement Phase**
- Advanced analytics and machine learning optimization
- Comprehensive performance monitoring and optimization
- Enhanced integration capabilities and third-party APIs

---

## Priority 1: Immediate Implementation (Week 1-2)

### **Database Schema Generation**
**Status:** Ready for implementation
**Timeline:** Days 1-3

**Deliverables:**
- Complete PostgreSQL table creation scripts with constraints
- Database indexes optimized for multi-tenant queries
- Row Level Security policies for tenant isolation
- Initial data seeding scripts for testing

**Key Components:**
```sql
-- Core tables with full constraints and indexes
CREATE TABLE tenants, hubs, users, customers, riders
CREATE TABLE orders, route_stops, pricing_rules
CREATE TABLE sync_queue, rider_locations

-- RLS policies for tenant separation
CREATE POLICY tenant_isolation_* ON *

-- Performance indexes
CREATE INDEX idx_orders_tenant_hub ON orders(tenant_id, hub_id)
CREATE INDEX idx_sync_queue_priority ON sync_queue(priority_level, created_at)
```

### **Dual Order Status System**
**Status:** Architecture defined, implementation needed
**Timeline:** Days 4-6

**Implementation Requirements:**
- **Operational Status:** Internal workflow management (`placed`, `confirmed`, `assigned`, `picked_up`, `delivered`, `cancelled`)
- **Customer Status:** User-facing display (`order_placed`, `confirmed`, `in_progress`, `completed`, `cancelled`)
- **Status Mapping:** Automatic conversion between operational and customer statuses
- **Progress Tracking:** Percentage-based progress calculation (0%, 25%, 50%, 85%, 100%)

**Database Design:**
```sql
-- Status mapping table
CREATE TABLE status_mappings (
    operational_status VARCHAR(50),
    customer_status VARCHAR(50),
    progress_percentage INTEGER,
    service_type VARCHAR(50)
);

-- Automated triggers for status conversion
CREATE TRIGGER update_customer_status
    AFTER UPDATE ON orders
    FOR EACH ROW EXECUTE update_customer_status_function();
```

### **API Integration Architecture**
**Status:** Framework design needed
**Timeline:** Days 7-10

**Core API Endpoints:**
- **Order Management API:** CRUD operations across all service types
- **Rider Management API:** Assignment, tracking, performance data
- **Real-Time Updates API:** Status changes, location updates, notifications
- **Admin Dashboard API:** Reporting, analytics, configuration management

**Authentication & Authorization:**
```javascript
// JWT token structure
{
  "user_id": "uuid",
  "tenant_id": "uuid", 
  "hub_id": "uuid",
  "role": "super_admin|hub_admin|dispatcher|rider|customer",
  "permissions": ["order:read", "rider:assign", "analytics:view"]
}
```

### **Reference Number Generation**
**Status:** Strategy design required
**Timeline:** Days 11-14

**Implementation Decision Points:**
- **Format:** Tenant-specific vs global numbering
- **Pattern:** Numeric vs alphanumeric (recommendation: `TENANT-HUB-YYYYMMDD-####`)
- **Uniqueness:** Database constraint enforcement
- **Recovery:** Handle sequence gaps and ensure no duplicates

**Recommended Implementation:**
```sql
CREATE SEQUENCE tenant_order_sequence;

CREATE OR REPLACE FUNCTION generate_reference_number(
    tenant_slug VARCHAR,
    hub_code VARCHAR
) RETURNS VARCHAR AS $$
DECLARE
    ref_number VARCHAR;
BEGIN
    ref_number := UPPER(tenant_slug) || '-' || 
                  UPPER(hub_code) || '-' || 
                  TO_CHAR(NOW(), 'YYYYMMDD') || '-' ||
                  LPAD(nextval('tenant_order_sequence')::TEXT, 4, '0');
    RETURN ref_number;
END;
$$ LANGUAGE plpgsql;
```

---

## Priority 2: Core Business Logic (Week 2-3)

### **Route Optimization API Integration**
**Status:** Interface definition required
**Timeline:** Days 15-18

**Algorithm Interface Requirements:**
- **Standardized Input Format:** Order locations, rider capacity, time windows, service requirements
- **Output Specification:** Optimized stop sequences with estimated times and distances
- **Algorithm Switching:** Support multiple optimization providers (Google Maps, custom algorithms)
- **Error Handling:** Fallback algorithms when primary optimization fails
- **Performance Metrics:** Response time tracking and algorithm comparison

**Integration Architecture:**
```javascript
// Route optimization request format
{
  "tenant_id": "uuid",
  "hub_id": "uuid",
  "orders": [
    {
      "order_id": "uuid",
      "pickup_location": {"lat": 14.5995, "lng": 120.9842},
      "delivery_location": {"lat": 14.6042, "lng": 120.9822},
      "service_type": "pickup_delivery",
      "priority": "normal",
      "time_window": {"start": "2024-01-01T10:00:00Z", "end": "2024-01-01T15:00:00Z"}
    }
  ],
  "rider_constraints": {
    "max_capacity": 40,
    "vehicle_type": "motorcycle",
    "work_schedule": {"start": "08:00", "end": "18:00"}
  },
  "optimization_config": {
    "algorithm": "google_maps_optimization",
    "distance_weight": 1.0,
    "time_weight": 1.2,
    "capacity_weight": 0.8
  }
}

// Response format
{
  "route_id": "uuid",
  "optimized_stops": [
    {
      "stop_sequence": 1,
      "order_id": "uuid",
      "stop_type": "pickup",
      "estimated_arrival": "2024-01-01T10:15:00Z",
      "estimated_duration_minutes": 5
    }
  ],
  "total_distance_km": 25.5,
  "total_duration_minutes": 180,
  "optimization_quality_score": 0.85
}
```

### **Emergency Order Processing**
**Status:** Logic design required
**Timeline:** Days 19-21

**Emergency Order Features:**
- **Priority Levels:** `emergency`, `high`, `normal`, `low`
- **Route Interruption:** `can_interrupt_routes` boolean flag for emergency orders
- **Capacity Override:** Emergency orders bypass normal capacity limits
- **Assignment Priority:** Immediate retry bypassing exponential backoff

**Implementation Logic:**
```sql
-- Emergency order handling function
CREATE OR REPLACE FUNCTION handle_emergency_order(
    order_id UUID,
    interrupt_routes BOOLEAN DEFAULT true
) RETURNS TABLE(affected_route_id UUID, reassignment_required BOOLEAN) AS $$
BEGIN
    -- Mark order as emergency priority
    UPDATE orders SET 
        priority = 'emergency',
        can_interrupt_routes = interrupt_routes
    WHERE id = order_id;
    
    -- If interruption allowed, identify affected routes
    IF interrupt_routes THEN
        RETURN QUERY
        SELECT r.id, true
        FROM routes r
        JOIN route_assignments ra ON r.id = ra.route_id
        WHERE ra.status = 'in_progress'
        AND ST_Distance(r.current_location, (SELECT pickup_location FROM orders WHERE id = order_id)) < 5000; -- 5km radius
    END IF;
END;
$$ LANGUAGE plpgsql;
```

### **Hub Transfer Coordination**
**Status:** Multi-hop logic design needed  
**Timeline:** Days 22-24

**Transfer Management System:**
- **Multi-Hop Support:** Hub A → Hub B → Hub C transfers
- **Sequence Tracking:** `transfer_sequence` numbers for audit trails
- **Status Flow:** `initiated` → `in_transit` → `arrived` → `completed` → `failed`
- **Capacity Validation:** Ensure receiving hub has capacity before transfer
- **Timing Coordination:** Optimize transfer timing between hubs

**Database Structure:**
```sql
CREATE TABLE hub_transfers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID NOT NULL REFERENCES orders(id),
    from_hub_id UUID NOT NULL REFERENCES hubs(id),
    to_hub_id UUID NOT NULL REFERENCES hubs(id),
    transfer_sequence INTEGER NOT NULL,
    status VARCHAR(50) DEFAULT 'initiated',
    estimated_arrival TIMESTAMPTZ,
    actual_arrival TIMESTAMPTZ,
    transfer_rider_id UUID REFERENCES riders(id),
    transfer_cost DECIMAL(8,2),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Multi-hop transfer orchestration
CREATE OR REPLACE FUNCTION create_transfer_chain(
    order_id UUID,
    hub_chain UUID[]
) RETURNS UUID[] AS $$
DECLARE
    transfer_ids UUID[] := '{}';
    i INTEGER;
BEGIN
    FOR i IN 1..array_length(hub_chain, 1)-1 LOOP
        INSERT INTO hub_transfers (order_id, from_hub_id, to_hub_id, transfer_sequence)
        VALUES (order_id, hub_chain[i], hub_chain[i+1], i)
        RETURNING id INTO transfer_ids[i];
    END LOOP;
    RETURN transfer_ids;
END;
$$ LANGUAGE plpgsql;
```

### **Pricing Engine Implementation**
**Status:** Calculation logic needed
**Timeline:** Days 25-28

**Pricing Models:**
- **Flat Rate:** Fixed charge regardless of distance/time
- **Base + Distance:** `base_fee + (distance × per_km_rate)`
- **Time-Based Schedules:** Different rates by time periods (e.g., night differential)
- **Service-Specific Pricing:** Different rates per service type

**Pricing Calculation Engine:**
```sql
CREATE OR REPLACE FUNCTION calculate_order_price(
    order_id UUID,
    distance_km DECIMAL DEFAULT NULL,
    estimated_duration_minutes INTEGER DEFAULT NULL
) RETURNS DECIMAL AS $$
DECLARE
    pricing_rule pricing_rules%ROWTYPE;
    schedule_multiplier DECIMAL := 1.0;
    final_price DECIMAL;
    order_info orders%ROWTYPE;
BEGIN
    -- Get order information
    SELECT * INTO order_info FROM orders WHERE id = order_id;
    
    -- Get applicable pricing rule
    SELECT * INTO pricing_rule
    FROM pricing_rules
    WHERE tenant_id = order_info.tenant_id
    AND hub_id = order_info.hub_id
    AND service_type = order_info.service_type
    AND is_active = true
    ORDER BY created_at DESC
    LIMIT 1;
    
    -- Check for active pricing schedule
    SELECT COALESCE(MAX(multiplier), 1.0) INTO schedule_multiplier
    FROM pricing_schedules
    WHERE tenant_id = order_info.tenant_id
    AND hub_id = order_info.hub_id
    AND is_active = true
    AND EXTRACT(DOW FROM NOW()) = ANY(day_of_week)
    AND NOW()::TIME BETWEEN start_time AND end_time;
    
    -- Calculate price based on pricing type
    IF pricing_rule.pricing_type = 'flat_rate' THEN
        final_price := pricing_rule.base_fee;
    ELSIF pricing_rule.pricing_type = 'base_plus_distance' AND distance_km IS NOT NULL THEN
        final_price := pricing_rule.base_fee + (distance_km * pricing_rule.per_km_rate);
    ELSE
        final_price := pricing_rule.base_fee; -- Fallback to base fee
    END IF;
    
    -- Apply schedule multiplier
    final_price := final_price * schedule_multiplier;
    
    RETURN final_price;
END;
$$ LANGUAGE plpgsql;
```

---

## Priority 3: Real-Time & Sync Systems (Week 3-4)

### **Redis Location Tracking Implementation**
**Status:** Data structure design needed
**Timeline:** Days 29-32

**Redis Data Structures:**
```javascript
// Active rider locations (1-hour expiry)
rider:location:{rider_id} = {
  "lat": 14.5995,
  "lng": 120.9842,
  "accuracy": 15.5,
  "timestamp": "2024-01-01T12:00:00Z",
  "speed": 25.5,
  "heading": 180
}

// Real-time route progress (2-hour expiry)
route:progress:{route_id} = {
  "current_stop": 3,
  "completed_stops": [1, 2],
  "estimated_completion": "2024-01-01T15:30:00Z",
  "total_distance_remaining": 12.5
}

// Customer tracking cache (4-hour expiry)
customer:tracking:{order_id} = {
  "rider_id": "uuid",
  "current_location": {"lat": 14.5995, "lng": 120.9842},
  "eta_minutes": 25,
  "status": "en_route_to_pickup"
}
```

**Location Processing Pipeline:**
1. **Mobile App** → Redis cache (immediate)
2. **Redis** → PostgreSQL (every 2 minutes, compressed)
3. **Customer Updates** → Socket.io broadcast (every 30 seconds)
4. **Analytics** → PostgreSQL route summaries (on completion)

### **Mobile Sync Protocol Design**
**Status:** Detailed workflow specification needed
**Timeline:** Days 33-35

**Sync Queue Processing:**
```javascript
// Sync queue item structure
{
  "id": "uuid",
  "rider_id": "uuid", 
  "operation_type": "task_completion|photo_upload|location_update|status_change",
  "priority_level": 1, // 1=highest, 5=lowest
  "data": {
    "order_id": "uuid",
    "completion_data": {...},
    "photos": ["base64_data"],
    "location": {"lat": 14.5995, "lng": 120.9842}
  },
  "max_attempts": 100, // Based on priority level
  "current_attempts": 0,
  "last_attempt_at": null,
  "needs_manual_review": false,
  "created_at": "2024-01-01T12:00:00Z"
}
```

**Sync Processing Logic:**
- **Batch Processing:** Group related operations for efficiency
- **Conflict Resolution:** Server-side conflict resolution with version control
- **Partial Sync Recovery:** Resume interrupted sync operations
- **Network Optimization:** Compress payloads for low-bandwidth scenarios

### **Real-Time Event System**
**Status:** Socket.io integration architecture
**Timeline:** Days 36-38

**Event Broadcasting System:**
```javascript
// Event types and routing
const eventTypes = {
  ORDER_STATUS_CHANGED: 'order:status_changed',
  RIDER_LOCATION_UPDATE: 'rider:location_update',
  ROUTE_OPTIMIZED: 'route:optimized',
  EMERGENCY_ORDER: 'emergency:order_created',
  DELIVERY_COMPLETED: 'delivery:completed'
};

// Selective broadcasting logic
function broadcastEvent(eventType, data, filters) {
  // Send to relevant users based on tenant, hub, and role
  const relevantSockets = sockets.filter(socket => {
    return socket.tenant_id === data.tenant_id &&
           (socket.role === 'admin' || socket.user_id === data.customer_id || socket.user_id === data.rider_id);
  });
  
  relevantSockets.forEach(socket => {
    socket.emit(eventType, data);
  });
}
```

**Connection Management:**
- **Connection Pooling:** Support 31K concurrent connections
- **Auto-Reconnection:** Robust reconnection with state recovery
- **Room Management:** Tenant/hub-based room segregation
- **Message Queuing:** Persist messages for offline users

### **Capacity Management System**
**Status:** Algorithm implementation needed
**Timeline:** Days 39-42

**Capacity Tracking:**
```sql
-- Real-time capacity monitoring
CREATE OR REPLACE FUNCTION get_rider_current_capacity(rider_id UUID)
RETURNS TABLE(current_orders INTEGER, max_capacity INTEGER, utilization_percentage DECIMAL) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::INTEGER as current_orders,
        r.max_capacity,
        ROUND((COUNT(*)::DECIMAL / r.max_capacity * 100), 2) as utilization_percentage
    FROM riders r
    LEFT JOIN route_assignments ra ON r.id = ra.rider_id
    LEFT JOIN routes rt ON ra.route_id = rt.id
    LEFT JOIN route_stops rs ON rt.id = rs.route_id
    WHERE r.id = rider_id
    AND ra.status = 'accepted'
    AND rs.completed_at IS NULL
    GROUP BY r.id, r.max_capacity;
END;
$$ LANGUAGE plpgsql;

-- Capacity-aware assignment
CREATE OR REPLACE FUNCTION find_available_riders(
    hub_id UUID,
    service_type VARCHAR,
    required_capacity INTEGER DEFAULT 1
) RETURNS TABLE(rider_id UUID, available_capacity INTEGER, efficiency_score DECIMAL) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        r.id,
        (r.max_capacity - COALESCE(current_assignments.order_count, 0))::INTEGER as available_capacity,
        r.efficiency_factor
    FROM riders r
    LEFT JOIN (
        SELECT 
            ra.rider_id,
            COUNT(*) as order_count
        FROM route_assignments ra
        JOIN routes rt ON ra.route_id = rt.id
        JOIN route_stops rs ON rt.id = rs.route_id
        WHERE ra.status = 'accepted'
        AND rs.completed_at IS NULL
        GROUP BY ra.rider_id
    ) current_assignments ON r.id = current_assignments.rider_id
    WHERE r.hub_id = hub_id
    AND r.status = 'available'
    AND (r.max_capacity - COALESCE(current_assignments.order_count, 0)) >= required_capacity
    ORDER BY r.efficiency_factor DESC;
END;
$$ LANGUAGE plpgsql;
```

---

---

## Outstanding Technical Decisions From Analysis

*Note: These decisions were identified during comprehensive platform analysis and require immediate architectural resolution before full implementation.*

### **Immediate Implementation Needs**

1. **Order Status System:** Implement dual status approach (operational + customer)
2. **Authentication Method:** Finalize JWT implementation details and session management
3. **Route Optimization APIs:** Define algorithm interfaces and data exchange formats
4. **Emergency Order Logic:** Implement priority-based route interruption and capacity override
5. **Capacity Management:** Implement rider capacity tracking and enforcement algorithms
6. **Reference Number Generation:** Define generation strategy and format (tenant-specific vs global)
7. **Real-time Location Processing:** Implement Redis + PostgreSQL hybrid processing architecture
8. **Sync Queue Processing:** Implement priority-based queue processing with automated cleanup

### **Configuration Requirements**

1. **Optimization Factors:** UI configuration to algorithm parameter mapping and validation
2. **Pricing Rules:** Time-based activation and pricing factor combination logic
3. **Work Schedule Integration:** Automatic route duration limits and break scheduling
4. **Hub Transfer Coordination:** Timing and capacity management between interconnected hubs
5. **Zone Priority Resolution:** Implement hub selection logic for overlapping delivery zones
6. **Emergency Order Policies:** Define capacity override rules and pricing premium calculations

### **Data Processing & Analytics Implementation**

1. **Route Performance Tracking:** Implement optimization improvement measurement and benchmarking
2. **Rider Performance Metrics:** Automated calculation of efficiency scores and performance analytics
3. **Location Data Compression:** Implement route polyline generation and street name capture
4. **Financial Reconciliation:** COD collection tracking and payment consistency validation workflows

### **Integration Architecture Requirements**

1. **Algorithm Interface Design:** Standardized input/output for optimization algorithms with fallback support
2. **Map Service Integration:** Google Maps and Mapbox API integration patterns and error handling
3. **Real-time Event Processing:** Socket.io event routing and delivery confirmation protocols
4. **Mobile Sync Protocol:** Offline queue synchronization API design with conflict resolution

### **Business Logic Implementation**

1. **Hub Transfer Orchestration:** Multi-hop transfer coordination and timing optimization
2. **Route Re-optimization Triggers:** Automated re-optimization condition handling and performance impact
3. **Capacity Overflow Management:** Handling procedures when system reaches capacity limits
4. **Time Window Validation:** Customer delivery window conflict resolution and alternative scheduling

---

## Critical Technical Decisions Requiring Immediate Resolution

### **1. Real-Time Data Synchronization Architecture**

**Decision Required:** Redis data structure design and PostgreSQL integration
**Impact:** Affects 450K location updates/hour processing capability
**Timeline:** Must be resolved by Day 29

**Options:**
- **Option A:** Simple Redis key-value with periodic PostgreSQL batch writes
- **Option B:** Redis Streams for ordered data processing with guaranteed delivery
- **Option C:** Hybrid approach with Redis for active data, immediate PostgreSQL writes for critical events

**Recommendation:** Option C for balance of performance and reliability

### **2. Mobile App Conflict Resolution Strategy**

**Decision Required:** How to handle data conflicts when mobile and server data diverge
**Impact:** Critical for offline-first functionality reliability
**Timeline:** Must be resolved by Day 33

**Conflict Scenarios:**
- Order status changed on both mobile and server while offline
- Location data sequence gaps during network outages
- Payment confirmation conflicts between mobile and server

**Resolution Strategy:**
- **Server Wins:** Server data always takes precedence (simple but may lose mobile work)
- **Timestamp Resolution:** Most recent timestamp wins (risk of clock skew)
- **Manual Review Queue:** Flag conflicts for human resolution (safest but requires overhead)

**Recommendation:** Hybrid approach - server wins for financial data, timestamp for status updates, manual review for complex conflicts

### **3. Route Optimization Algorithm Selection**

**Decision Required:** Primary optimization algorithm and fallback strategy
**Impact:** Core feature affecting delivery efficiency and customer satisfaction
**Timeline:** Must be resolved by Day 15

**Algorithm Options:**
- **Google Maps Routes API:** Reliable but external dependency and cost
- **Custom Genetic Algorithm:** Full control but development complexity
- **Open Source Solutions:** TSP solvers, OR-Tools integration

**Recommendation:** Start with Google Maps API, develop custom algorithm for cost optimization

### **4. Payment Gateway Integration Architecture**

**Decision Required:** Payment processing workflow and failure handling
**Impact:** Revenue processing and financial reconciliation
**Timeline:** Must be resolved by Day 35

**Integration Points:**
- Order creation with payment authorization
- COD collection confirmation
- Payment failure and retry logic
- Multi-currency support preparation

---

## Success Metrics & Quality Assurance

### **Performance Benchmarks**
- **Response Time Compliance:** >95% of API calls under target response times
- **Sync Success Rate:** >99% success rate for critical financial data sync
- **Location Accuracy:** >95% of location updates within 50m accuracy threshold
- **Route Optimization Quality:** >80% improvement over manual route planning

### **Scale Validation**
- **Load Testing:** Simulate 10,000 orders/day with 450K location updates/hour
- **Concurrent User Testing:** Verify 31K simultaneous Socket.io connections
- **Database Performance:** Query response times under 100ms for critical operations
- **Mobile App Performance:** Offline operation for 24+ hours without data loss

### **Integration Testing Strategy**
- **End-to-End Workflows:** Complete order lifecycle testing for all service types
- **Cross-Platform Testing:** Data consistency across Admin Dashboard, Rider App, Customer App, Merchant App
- **Offline/Online Transitions:** Mobile app sync testing with network interruptions
- **Multi-Tenant Isolation:** Verify complete data separation between tenants

### **Security Validation**
- **Penetration Testing:** Security assessment of authentication and data access
- **SQL Injection Protection:** Comprehensive testing of parameterized queries
- **Row Level Security Verification:** Confirm tenant isolation under various access patterns
- **Payment Data Security:** PCI compliance validation for payment processing

This development roadmap provides a comprehensive path to production-ready deployment within the 4-week timeline while addressing all critical technical challenges and ensuring scalable, reliable operation for the target business requirements.