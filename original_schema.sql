-- =========================================
-- Airship Lite - Updated Complete Database Schema
-- =========================================
-- Multi-tenant delivery management platform
-- Database: PostgreSQL 15+ with PostGIS extension
-- Updated: Separated customers and riders from users table
-- =========================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis";

-- =========================================
-- 1. TENANT & ORGANIZATION MANAGEMENT
-- =========================================

-- Master tenant/client accounts
CREATE TABLE tenants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(100) UNIQUE NOT NULL,
    email VARCHAR(255) NOT NULL,
    phone VARCHAR(20),
    settings JSONB DEFAULT '{}',
    subscription_plan VARCHAR(50) DEFAULT 'basic',
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'inactive')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Physical locations/branches per tenant
CREATE TABLE hubs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    address TEXT NOT NULL,
    city VARCHAR(100) NOT NULL,
    country VARCHAR(50) DEFAULT 'PH',
    location GEOGRAPHY(POINT, 4326),
    delivery_radius_km DECIMAL(8,2) DEFAULT 10.0,
    business_hours JSONB,
    service_types TEXT[] DEFAULT ARRAY['pickup_delivery'],
    settings JSONB DEFAULT '{}',
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'maintenance')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Polygon-based service area definitions with priority rules
CREATE TABLE hub_delivery_zones (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    hub_id UUID NOT NULL REFERENCES hubs(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    boundary GEOGRAPHY(POLYGON, 4326) NOT NULL,
    priority INTEGER DEFAULT 5,
    pricing_tier VARCHAR(50),
    overlap_resolution VARCHAR(50) DEFAULT 'priority',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =========================================
-- 2. USER MANAGEMENT & AUTHENTICATION
-- =========================================

-- Platform-level customers (separated from employees)
CREATE TABLE customers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL 
        CONSTRAINT valid_customer_email CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
    phone VARCHAR(20) 
        CONSTRAINT valid_customer_phone CHECK (phone IS NULL OR phone ~* '^\+?[1-9]\d{1,14}$'),
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    password_hash VARCHAR(255),
    email_verified_at TIMESTAMPTZ,
    email_verification_token VARCHAR(255),
    phone_verified_at TIMESTAMPTZ,
    phone_verification_token VARCHAR(10),
    language_preference VARCHAR(10) DEFAULT 'en',
    timezone VARCHAR(50) DEFAULT 'Asia/Manila',
    notification_preferences JSONB DEFAULT '{"email": true, "sms": true, "push": true}',
    profile_picture_url VARCHAR(500),
    date_of_birth DATE,
    failed_login_attempts INTEGER DEFAULT 0,
    locked_until TIMESTAMPTZ,
    status VARCHAR(20) DEFAULT 'active' 
        CHECK (status IN ('pending', 'active', 'suspended', 'inactive', 'locked')),
    last_login_at TIMESTAMPTZ,
    last_login_ip INET,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Employee users (admins, dispatchers only)
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    hub_id UUID REFERENCES hubs(id) ON DELETE SET NULL,
    email VARCHAR(255) UNIQUE NOT NULL 
        CONSTRAINT valid_user_email CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
    phone VARCHAR(20) 
        CONSTRAINT valid_user_phone CHECK (phone IS NULL OR phone ~* '^\+?[1-9]\d{1,14}$'),
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    role VARCHAR(50) NOT NULL CHECK (role IN ('admin', 'dispatcher')),
    password_hash VARCHAR(255),
    email_verified_at TIMESTAMPTZ,
    email_verification_token VARCHAR(255),
    mfa_enabled BOOLEAN DEFAULT false,
    mfa_secret VARCHAR(255),
    failed_login_attempts INTEGER DEFAULT 0,
    locked_until TIMESTAMPTZ,
    status VARCHAR(20) DEFAULT 'active' 
        CHECK (status IN ('pending', 'active', 'suspended', 'inactive', 'locked')),
    last_login_at TIMESTAMPTZ,
    last_login_ip INET,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Field workers/delivery personnel (separated from users)
CREATE TABLE riders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    hub_id UUID NOT NULL REFERENCES hubs(id) ON DELETE CASCADE,
    rider_group_id UUID REFERENCES rider_groups(id) ON DELETE SET NULL,
    
    -- Authentication & Profile
    email VARCHAR(255) UNIQUE NOT NULL 
        CONSTRAINT valid_rider_email CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
    phone VARCHAR(20) NOT NULL 
        CONSTRAINT valid_rider_phone CHECK (phone ~* '^\+?[1-9]\d{1,14}$'),
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    password_hash VARCHAR(255),
    date_of_birth DATE,
    emergency_contact_name VARCHAR(255),
    emergency_contact_phone VARCHAR(20),
    
    -- Vehicle & Capacity Management
    vehicle_type VARCHAR(50) NOT NULL CHECK (vehicle_type IN ('motorcycle', 'car', 'van', 'bicycle')),
    license_number VARCHAR(100),
    vehicle_capacity INTEGER DEFAULT 10,
    max_volume_liters DECIMAL(8,2),
    max_weight_kg DECIMAL(8,2),
    current_capacity_used INTEGER DEFAULT 0,
    
    -- Operational Data
    efficiency_score DECIMAL(4,2) DEFAULT 1.0,
    current_location GEOGRAPHY(POINT, 4326),
    assigned_area GEOGRAPHY(POLYGON, 4326),
    
    -- Performance & Rating
    rating DECIMAL(3,2) DEFAULT 5.0,
    total_deliveries INTEGER DEFAULT 0,
    can_handle_emergency BOOLEAN DEFAULT false,
    is_verified BOOLEAN DEFAULT false,
    
    -- Mobile App Specific
    app_version VARCHAR(20),
    device_id VARCHAR(255),
    push_notification_token VARCHAR(500),
    last_location_update TIMESTAMPTZ,
    email_verified_at TIMESTAMPTZ,
    failed_login_attempts INTEGER DEFAULT 0,
    locked_until TIMESTAMPTZ,
    
    -- Scheduling & Status
    work_schedule JSONB,
    status VARCHAR(20) DEFAULT 'offline' 
        CHECK (status IN ('offline', 'available', 'busy', 'break', 'inactive')),
    account_status VARCHAR(20) DEFAULT 'active' 
        CHECK (account_status IN ('pending', 'active', 'suspended', 'inactive', 'locked')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Simple organizational rider groupings
CREATE TABLE rider_groups (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    hub_id UUID NOT NULL REFERENCES hubs(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    settings JSONB DEFAULT '{}',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Saved delivery addresses per customer (no tenant_id - global addresses)
CREATE TABLE customer_addresses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    label VARCHAR(100),
    address TEXT NOT NULL,
    location GEOGRAPHY(POINT, 4326) NOT NULL,
    delivery_instructions TEXT,
    is_default BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =========================================
-- 3. PRODUCT & SERVICE MANAGEMENT
-- =========================================

-- Product/service categorization
CREATE TABLE categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    hub_id UUID REFERENCES hubs(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    service_type VARCHAR(50) NOT NULL,
    display_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Menu items, services, transportable goods
CREATE TABLE products (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    hub_id UUID NOT NULL REFERENCES hubs(id) ON DELETE CASCADE,
    category_id UUID REFERENCES categories(id) ON DELETE SET NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    base_price DECIMAL(10,2) NOT NULL,
    service_type VARCHAR(50) NOT NULL,
    variations JSONB,
    is_available BOOLEAN DEFAULT true,
    display_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Time-based product availability
CREATE TABLE product_availability_schedules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    day_of_week INTEGER NOT NULL CHECK (day_of_week >= 0 AND day_of_week <= 6),
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Simplified flexible pricing per service type
CREATE TABLE pricing_rules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    hub_id UUID REFERENCES hubs(id) ON DELETE CASCADE,
    service_type VARCHAR(50) NOT NULL,
    name VARCHAR(255) NOT NULL,
    pricing_model VARCHAR(50) DEFAULT 'flat_rate' CHECK (pricing_model IN ('flat_rate', 'base_plus_distance')),
    base_price DECIMAL(10,2) NOT NULL,
    price_per_km DECIMAL(10,2) DEFAULT 0,
    minimum_price DECIMAL(10,2),
    maximum_price DECIMAL(10,2),
    factors JSONB DEFAULT '{}',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Time-based pricing activation
CREATE TABLE pricing_schedules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pricing_rule_id UUID NOT NULL REFERENCES pricing_rules(id) ON DELETE CASCADE,
    day_of_week INTEGER NOT NULL CHECK (day_of_week >= 0 AND day_of_week <= 6),
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    multiplier DECIMAL(4,2) DEFAULT 1.0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =========================================
-- 4. ORDER PROCESSING SYSTEM
-- =========================================

-- Master order table with hub transfer support
CREATE TABLE orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    hub_id UUID NOT NULL REFERENCES hubs(id) ON DELETE CASCADE,
    origin_hub_id UUID NOT NULL REFERENCES hubs(id),
    destination_hub_id UUID REFERENCES hubs(id),
    transfer_sequence INTEGER DEFAULT 1,
    transfer_reason TEXT,
    customer_id UUID REFERENCES customers(id) ON DELETE SET NULL,
    rider_id UUID REFERENCES riders(id) ON DELETE SET NULL,
    reference_number VARCHAR(20) UNIQUE NOT NULL,
    service_type VARCHAR(50) NOT NULL,
    status VARCHAR(50) DEFAULT 'placed',
    priority VARCHAR(20) DEFAULT 'normal' CHECK (priority IN ('emergency', 'high', 'normal', 'low')),
    can_interrupt_routes BOOLEAN DEFAULT false,
    customer_name VARCHAR(255) NOT NULL,
    customer_phone VARCHAR(20) NOT NULL,
    customer_email VARCHAR(255),
    pickup_address TEXT,
    pickup_location GEOGRAPHY(POINT, 4326),
    pickup_instructions TEXT,
    delivery_address TEXT NOT NULL,
    delivery_location GEOGRAPHY(POINT, 4326) NOT NULL,
    delivery_instructions TEXT,
    delivery_address_id UUID REFERENCES customer_addresses(id),
    scheduled_pickup_time TIMESTAMPTZ,
    scheduled_delivery_time TIMESTAMPTZ,
    pickup_time_window_start TIMESTAMPTZ,
    pickup_time_window_end TIMESTAMPTZ,
    delivery_time_window_start TIMESTAMPTZ,
    delivery_time_window_end TIMESTAMPTZ,
    payment_method VARCHAR(50) DEFAULT 'cod',
    payment_status VARCHAR(20) DEFAULT 'pending',
    subtotal DECIMAL(10,2),
    tax_amount DECIMAL(10,2),
    delivery_fee DECIMAL(10,2),
    tip_amount DECIMAL(10,2) DEFAULT 0,
    total_amount DECIMAL(10,2) NOT NULL,
    special_instructions TEXT,
    proof_of_delivery_url VARCHAR(500),
    actual_pickup_time TIMESTAMPTZ,
    actual_delivery_time TIMESTAMPTZ,
    estimated_delivery_time TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Hybrid service-specific data (columns + JSONB)
CREATE TABLE order_details (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    service_type VARCHAR(50) NOT NULL,
    
    -- Food delivery specific
    restaurant_id UUID,
    preparation_time_minutes INTEGER,
    special_dietary_requirements TEXT,
    
    -- Transportation specific  
    passenger_count INTEGER,
    vehicle_type_requested VARCHAR(50),
    trip_type VARCHAR(50),
    
    -- Shopping/Errands specific
    shopping_list TEXT,
    estimated_cost DECIMAL(10,2),
    receipt_required BOOLEAN DEFAULT false,
    
    -- Pickup/Delivery specific
    package_description TEXT,
    package_value DECIMAL(10,2),
    package_weight_kg DECIMAL(8,2),
    package_dimensions VARCHAR(100),
    fragile BOOLEAN DEFAULT false,
    requires_signature BOOLEAN DEFAULT false,
    
    -- Flexible additional data
    additional_data JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Line items for orders (food, shopping, etc.)
CREATE TABLE order_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id UUID REFERENCES products(id) ON DELETE SET NULL,
    name VARCHAR(255) NOT NULL,
    quantity INTEGER DEFAULT 1,
    unit_price DECIMAL(10,2) NOT NULL,
    total_price DECIMAL(10,2) NOT NULL,
    variations JSONB,
    special_instructions TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Complete audit trail of status changes
CREATE TABLE order_status_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    status VARCHAR(50) NOT NULL,
    previous_status VARCHAR(50),
    changed_by_user_id UUID REFERENCES users(id),
    changed_by_rider_id UUID REFERENCES riders(id),
    location GEOGRAPHY(POINT, 4326),
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT status_changed_by_check 
    CHECK ((changed_by_user_id IS NOT NULL) != (changed_by_rider_id IS NOT NULL))
);

-- =========================================
-- 5. ROUTE & TASK MANAGEMENT
-- =========================================

-- Tenant-specific optimization algorithm configuration
CREATE TABLE optimization_configurations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    algorithm_type VARCHAR(50) NOT NULL,
    factors JSONB NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Rider work schedule and shift management
CREATE TABLE rider_work_schedules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    rider_id UUID NOT NULL REFERENCES riders(id) ON DELETE CASCADE,
    day_of_week INTEGER NOT NULL CHECK (day_of_week >= 0 AND day_of_week <= 6),
    shift_start TIME NOT NULL,
    shift_end TIME NOT NULL,
    max_duration_minutes INTEGER DEFAULT 480,
    break_duration_minutes INTEGER DEFAULT 60,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Optimized delivery routes with configuration-driven optimization
CREATE TABLE routes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    hub_id UUID NOT NULL REFERENCES hubs(id) ON DELETE CASCADE,
    rider_id UUID REFERENCES riders(id) ON DELETE SET NULL,
    optimization_config_id UUID REFERENCES optimization_configurations(id),
    route_name VARCHAR(255),
    route_type VARCHAR(20) DEFAULT 'delivery',
    status VARCHAR(50) DEFAULT 'new',
    max_stops INTEGER DEFAULT 20,
    current_stops_count INTEGER DEFAULT 0,
    max_duration_minutes INTEGER,
    algorithm_used VARCHAR(50),
    algorithm_version VARCHAR(20),
    optimization_score DECIMAL(8,4),
    original_distance_km DECIMAL(8,2),
    optimized_distance_km DECIMAL(8,2),
    time_saved_minutes INTEGER,
    total_distance_km DECIMAL(8,2),
    estimated_duration_minutes INTEGER,
    actual_duration_minutes INTEGER,
    paused_at TIMESTAMPTZ,
    pause_duration_minutes INTEGER DEFAULT 0,
    can_accept_emergency BOOLEAN DEFAULT true,
    planned_start_time TIMESTAMPTZ,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    raw_algorithm_data JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Individual pickup/delivery points in routes
CREATE TABLE route_stops (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    route_id UUID NOT NULL REFERENCES routes(id) ON DELETE CASCADE,
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    stop_sequence INTEGER NOT NULL,
    stop_type VARCHAR(20) NOT NULL CHECK (stop_type IN ('pickup', 'delivery')),
    address TEXT NOT NULL,
    location GEOGRAPHY(POINT, 4326) NOT NULL,
    planned_arrival_time TIMESTAMPTZ,
    actual_arrival_time TIMESTAMPTZ,
    planned_departure_time TIMESTAMPTZ,
    actual_departure_time TIMESTAMPTZ,
    estimated_duration_minutes INTEGER,
    actual_duration_minutes INTEGER,
    status VARCHAR(20) DEFAULT 'pending',
    is_manual_override BOOLEAN DEFAULT false,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Route assignment with individual and group support
CREATE TABLE route_assignments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    route_id UUID NOT NULL REFERENCES routes(id) ON DELETE CASCADE,
    rider_id UUID REFERENCES riders(id) ON DELETE CASCADE,
    rider_group_id UUID REFERENCES rider_groups(id) ON DELETE CASCADE,
    assigned_by UUID NOT NULL REFERENCES users(id),
    assignment_type VARCHAR(20) NOT NULL CHECK (assignment_type IN ('individual', 'group')),
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected')),
    assigned_at TIMESTAMPTZ DEFAULT NOW(),
    responded_at TIMESTAMPTZ,
    rejection_reason TEXT,
    
    CONSTRAINT assignment_target_check 
    CHECK ((rider_id IS NOT NULL) != (rider_group_id IS NOT NULL))
);

-- Route optimization history and performance tracking
CREATE TABLE route_optimizations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    route_id UUID NOT NULL REFERENCES routes(id) ON DELETE CASCADE,
    optimization_config_id UUID REFERENCES optimization_configurations(id),
    optimization_trigger VARCHAR(50) NOT NULL,
    algorithm_used VARCHAR(50) NOT NULL,
    algorithm_version VARCHAR(20),
    previous_sequence INTEGER[],
    new_sequence INTEGER[],
    distance_before_km DECIMAL(8,2),
    distance_after_km DECIMAL(8,2),
    time_before_minutes INTEGER,
    time_after_minutes INTEGER,
    improvement_percentage DECIMAL(5,2),
    optimization_duration_ms INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Manual route modifications audit trail
CREATE TABLE route_edit_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    route_id UUID NOT NULL REFERENCES routes(id) ON DELETE CASCADE,
    edited_by UUID NOT NULL REFERENCES users(id),
    edit_type VARCHAR(50) NOT NULL,
    old_values JSONB,
    new_values JSONB,
    reason TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Inter-hub transfer tracking with sequence support
CREATE TABLE hub_transfers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    transfer_sequence INTEGER NOT NULL,
    from_hub_id UUID NOT NULL REFERENCES hubs(id),
    to_hub_id UUID NOT NULL REFERENCES hubs(id),
    from_rider_id UUID REFERENCES riders(id),
    to_rider_id UUID REFERENCES riders(id),
    status VARCHAR(20) DEFAULT 'initiated',
    initiated_at TIMESTAMPTZ DEFAULT NOW(),
    departed_at TIMESTAMPTZ,
    arrived_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    transfer_notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =========================================
-- 6. LOCATION & TRACKING
-- =========================================

-- Route analytics with street names and customer sharing
CREATE TABLE order_route_tracking (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    rider_id UUID NOT NULL REFERENCES riders(id) ON DELETE CASCADE,
    route_points GEOGRAPHY(LINESTRING, 4326),
    street_names TEXT[],
    total_distance_km DECIMAL(8,2),
    travel_duration_minutes INTEGER,
    average_speed_kmh DECIMAL(5,2),
    share_with_customer BOOLEAN DEFAULT true,
    tracking_started_at TIMESTAMPTZ,
    tracking_ended_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- GPS accuracy monitoring with 50m threshold
CREATE TABLE location_accuracy_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    rider_id UUID NOT NULL REFERENCES riders(id) ON DELETE CASCADE,
    order_id UUID REFERENCES orders(id) ON DELETE CASCADE,
    location GEOGRAPHY(POINT, 4326) NOT NULL,
    accuracy_meters DECIMAL(8,2) NOT NULL,
    meets_threshold BOOLEAN NOT NULL,
    location_source VARCHAR(20),
    battery_level INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =========================================
-- 7. RATINGS & PERFORMANCE
-- =========================================

-- Customer ratings for riders (1-5 scale)
CREATE TABLE order_ratings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    customer_id UUID REFERENCES customers(id) ON DELETE SET NULL,
    rider_id UUID NOT NULL REFERENCES riders(id) ON DELETE CASCADE,
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    review_text TEXT,
    service_quality_rating INTEGER CHECK (service_quality_rating >= 1 AND service_quality_rating <= 5),
    delivery_time_rating INTEGER CHECK (delivery_time_rating >= 1 AND delivery_time_rating <= 5),
    communication_rating INTEGER CHECK (communication_rating >= 1 AND communication_rating <= 5),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Calculated performance statistics
CREATE TABLE rider_performance_metrics (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    rider_id UUID NOT NULL REFERENCES riders(id) ON DELETE CASCADE,
    calculation_date DATE NOT NULL,
    total_orders INTEGER DEFAULT 0,
    completed_orders INTEGER DEFAULT 0,
    cancelled_orders INTEGER DEFAULT 0,
    average_rating DECIMAL(3,2),
    average_delivery_time_minutes INTEGER,
    on_time_delivery_rate DECIMAL(5,2),
    total_distance_km DECIMAL(10,2),
    total_earnings DECIMAL(10,2),
    efficiency_score DECIMAL(4,2),
    customer_satisfaction_score DECIMAL(4,2),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(rider_id, calculation_date)
);

-- =========================================
-- 8. REAL-TIME & SYNC MANAGEMENT
-- =========================================

-- Priority-based offline sync with limits
CREATE TABLE sync_queue (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    rider_id UUID NOT NULL REFERENCES riders(id) ON DELETE CASCADE,
    operation_type VARCHAR(50) NOT NULL,
    priority INTEGER NOT NULL,
    payload JSONB NOT NULL,
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
    attempts INTEGER DEFAULT 0,
    max_attempts INTEGER DEFAULT 50,
    next_retry_at TIMESTAMPTZ DEFAULT NOW(),
    last_error TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    auto_cleanup_at TIMESTAMPTZ
);

-- Minimal event audit trail (Redis primary)
CREATE TABLE real_time_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_type VARCHAR(50) NOT NULL,
    entity_type VARCHAR(50) NOT NULL,
    entity_id UUID NOT NULL,
    user_id UUID REFERENCES users(id),
    rider_id UUID REFERENCES riders(id),
    customer_id UUID REFERENCES customers(id),
    event_data JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =========================================
-- 9. FINANCIAL & AUDIT
-- =========================================

-- All payment processing records
CREATE TABLE payment_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    transaction_type VARCHAR(50) NOT NULL,
    payment_method VARCHAR(50) NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'PHP',
    status VARCHAR(20) NOT NULL,
    gateway_provider VARCHAR(50),
    gateway_transaction_id VARCHAR(255),
    gateway_response JSONB,
    processed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Cash on delivery tracking with consistency rules
CREATE TABLE cod_collections (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    rider_id UUID NOT NULL REFERENCES riders(id) ON DELETE CASCADE,
    amount_collected DECIMAL(10,2) NOT NULL,
    collection_method VARCHAR(20) DEFAULT 'cash',
    collected_at TIMESTAMPTZ DEFAULT NOW(),
    reconciled_at TIMESTAMPTZ,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Complete financial transaction audit trail
CREATE TABLE financial_audit_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    transaction_type VARCHAR(50) NOT NULL,
    entity_type VARCHAR(50) NOT NULL,
    entity_id UUID NOT NULL,
    user_id UUID REFERENCES users(id),
    rider_id UUID REFERENCES riders(id),
    old_values JSONB,
    new_values JSONB,
    amount_involved DECIMAL(10,2),
    audit_reason TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT audit_actor_check 
    CHECK ((user_id IS NOT NULL) != (rider_id IS NOT NULL))
);

-- =========================================
-- INDEXES FOR PERFORMANCE OPTIMIZATION
-- =========================================

-- Multi-Tenant Isolation
CREATE INDEX idx_orders_tenant_hub ON orders(tenant_id, hub_id);
CREATE INDEX idx_riders_tenant_hub ON riders(tenant_id, hub_id);
CREATE INDEX idx_users_tenant_role ON users(tenant_id, role);
CREATE INDEX idx_products_tenant_hub ON products(tenant_id, hub_id);

-- Order Management (High Priority)
CREATE INDEX idx_orders_status_created ON orders(status, created_at DESC);
CREATE INDEX idx_orders_rider_status ON orders(rider_id, status) WHERE rider_id IS NOT NULL;
CREATE INDEX idx_orders_service_type_status ON orders(service_type, status);
CREATE INDEX idx_orders_customer_created ON orders(customer_id, created_at DESC);
CREATE INDEX idx_orders_reference_number ON orders(reference_number);
CREATE INDEX idx_orders_customer_tracking ON orders(customer_id, status, created_at DESC);

-- Customer Management
CREATE INDEX idx_customers_email_status ON customers(email, status);
CREATE INDEX idx_customer_addresses_customer_default ON customer_addresses(customer_id, is_default);

-- Rider Management
CREATE INDEX idx_riders_hub_status ON riders(hub_id, status);
CREATE INDEX idx_riders_status_location ON riders(status) WHERE current_location IS NOT NULL;
CREATE INDEX idx_riders_capacity_status ON riders(vehicle_capacity, current_capacity_used, status);
CREATE INDEX idx_riders_email_status ON riders(email, account_status);

-- Location & Spatial Operations
CREATE INDEX idx_order_route_tracking_spatial ON order_route_tracking USING GIST(route_points);
CREATE INDEX idx_hub_delivery_zones_spatial ON hub_delivery_zones USING GIST(boundary);
CREATE INDEX idx_hub_delivery_zones_priority ON hub_delivery_zones(priority, is_active);
CREATE INDEX idx_orders_pickup_location ON orders USING GIST(pickup_location);
CREATE INDEX idx_orders_delivery_location ON orders USING GIST(delivery_location);
CREATE INDEX idx_riders_current_location ON riders USING GIST(current_location);

-- Real-time & Sync Performance
CREATE INDEX idx_sync_queue_priority_status ON sync_queue(priority, status, next_retry_at) WHERE status = 'pending';
CREATE INDEX idx_sync_queue_rider_priority ON sync_queue(rider_id, priority) WHERE status = 'pending';
CREATE INDEX idx_sync_queue_cleanup ON sync_queue(auto_cleanup_at) WHERE status = 'completed';

-- Hub Transfer Operations
CREATE INDEX idx_orders_origin_destination ON orders(origin_hub_id, destination_hub_id);
CREATE INDEX idx_orders_transfer_sequence ON orders(transfer_sequence, status);
CREATE INDEX idx_hub_transfers_order_sequence ON hub_transfers(order_id, transfer_sequence);

-- Product Management
CREATE INDEX idx_products_service_available ON products(service_type, is_available);
CREATE INDEX idx_product_availability_schedules_active ON product_availability_schedules(product_id, day_of_week, is_active);
CREATE INDEX idx_pricing_rules_tenant_service_active ON pricing_rules(tenant_id, service_type, is_active);

-- Route Optimization
CREATE INDEX idx_optimization_configs_tenant_active ON optimization_configurations(tenant_id, is_active);
CREATE INDEX idx_routes_optimization_config ON routes(optimization_config_id);
CREATE INDEX idx_route_assignments_route_status ON route_assignments(route_id, status);
CREATE INDEX idx_route_assignments_rider_status ON route_assignments(rider_id, status) WHERE rider_id IS NOT NULL;
CREATE INDEX idx_route_assignments_group_status ON route_assignments(rider_group_id, status) WHERE rider_group_id IS NOT NULL;
CREATE INDEX idx_route_optimizations_route_trigger ON route_optimizations(route_id, optimization_trigger, created_at);
CREATE INDEX idx_route_optimizations_config ON route_optimizations(optimization_config_id, created_at);
CREATE INDEX idx_route_edit_history_route_type ON route_edit_history(route_id, edit_type, created_at);
CREATE INDEX idx_route_stops_override ON route_stops(route_id, is_manual_override);
CREATE INDEX idx_rider_work_schedules_rider_day ON rider_work_schedules(rider_id, day_of_week, is_active);

-- Emergency and Priority Orders
CREATE INDEX idx_orders_priority_interrupt ON orders(priority, can_interrupt_routes) WHERE priority != 'normal';
CREATE INDEX idx_routes_emergency_capacity ON routes(can_accept_emergency, current_stops_count, max_stops);

-- Financial & Audit
CREATE INDEX idx_payment_transactions_order_status ON payment_transactions(order_id, status);
CREATE INDEX idx_cod_collections_rider_collected ON cod_collections(rider_id, collected_at);
CREATE INDEX idx_financial_audit_log_entity ON financial_audit_log(entity_type, entity_id, created_at);

-- Authentication & Security
CREATE INDEX idx_customers_email_verification ON customers(email_verification_token) WHERE email_verification_token IS NOT NULL;
CREATE INDEX idx_users_email_verification ON users(email_verification_token) WHERE email_verification_token IS NOT NULL;
CREATE INDEX idx_riders_device_push_token ON riders(device_id, push_notification_token) WHERE push_notification_token IS NOT NULL;

-- Performance & Rating
CREATE INDEX idx_order_ratings_rider_created ON order_ratings(rider_id, created_at DESC);
CREATE INDEX idx_rider_performance_metrics_rider_date ON rider_performance_metrics(rider_id, calculation_date DESC);