
-- =========================================
-- ROW LEVEL SECURITY POLICIES
-- =========================================

-- Enable RLS on all tenant-scoped tables
ALTER TABLE tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE hubs ENABLE ROW LEVEL SECURITY;
ALTER TABLE hub_delivery_zones ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE riders ENABLE ROW LEVEL SECURITY;
ALTER TABLE rider_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE pricing_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE routes ENABLE ROW LEVEL SECURITY;

-- Tenant isolation policies
CREATE POLICY tenant_isolation_tenants ON tenants
    FOR ALL USING (id = current_setting('app.current_tenant_id')::UUID);

CREATE POLICY tenant_isolation_hubs ON hubs
    FOR ALL USING (tenant_id = current_setting('app.current_tenant_id')::UUID);

CREATE POLICY tenant_isolation_users ON users
    FOR ALL USING (tenant_id = current_setting('app.current_tenant_id')::UUID);

CREATE POLICY tenant_isolation_riders ON riders
    FOR ALL USING (tenant_id = current_setting('app.current_tenant_id')::UUID);

CREATE POLICY tenant_isolation_orders ON orders
    FOR ALL USING (tenant_id = current_setting('app.current_tenant_id')::UUID);

CREATE POLICY tenant_isolation_routes ON routes
    FOR ALL USING (tenant_id = current_setting('app.current_tenant_id')::UUID);

-- Rider self-access policy
CREATE POLICY rider_self_access ON riders
    FOR ALL USING (id = current_setting('app.current_rider_id')::UUID);

-- Customer self-access policy (no RLS on customers table - platform level)
-- Customer addresses are accessible by the customer who owns them
ALTER TABLE customer_addresses ENABLE ROW LEVEL SECURITY;
CREATE POLICY customer_address_access ON customer_addresses
    FOR ALL USING (customer_id = current_setting('app.current_customer_id')::UUID);

-- =========================================
-- TRIGGERS FOR AUTOMATIC UPDATES
-- =========================================

-- Auto-update timestamp triggers
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$ LANGUAGE plpgsql;

CREATE TRIGGER tenants_updated_at_trigger
    BEFORE UPDATE ON tenants
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER hubs_updated_at_trigger
    BEFORE UPDATE ON hubs
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER customers_updated_at_trigger
    BEFORE UPDATE ON customers
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER users_updated_at_trigger
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER riders_updated_at_trigger
    BEFORE UPDATE ON riders
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER products_updated_at_trigger
    BEFORE UPDATE ON products
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER pricing_rules_updated_at_trigger
    BEFORE UPDATE ON pricing_rules
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER orders_updated_at_trigger
    BEFORE UPDATE ON orders
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER routes_updated_at_trigger
    BEFORE UPDATE ON routes
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Order status history trigger
CREATE OR REPLACE FUNCTION log_order_status_change()
RETURNS TRIGGER AS $
BEGIN
    IF OLD.status IS DISTINCT FROM NEW.status THEN
        INSERT INTO order_status_history (
            order_id,
            status,
            previous_status,
            changed_by_user_id,
            changed_by_rider_id,
            notes
        ) VALUES (
            NEW.id,
            NEW.status,
            OLD.status,
            current_setting('app.current_user_id', true)::UUID,
            current_setting('app.current_rider_id', true)::UUID,
            'Automatic status change'
        );
    END IF;
    RETURN NEW;
END;
$ LANGUAGE plpgsql;

CREATE TRIGGER order_status_change_trigger
    AFTER UPDATE ON orders
    FOR EACH ROW
    EXECUTE FUNCTION log_order_status_change();

-- Rider capacity tracking trigger
CREATE OR REPLACE FUNCTION update_rider_capacity()
RETURNS TRIGGER AS $
BEGIN
    -- Recalculate rider capacity when route assignments change
    UPDATE riders SET 
        current_capacity_used = (
            SELECT COALESCE(SUM(r.current_stops_count), 0)
            FROM routes r
            WHERE r.rider_id = COALESCE(NEW.rider_id, OLD.rider_id)
            AND r.status IN ('active', 'assigned')
        )
    WHERE id = COALESCE(NEW.rider_id, OLD.rider_id);
    
    RETURN COALESCE(NEW, OLD);
END;
$ LANGUAGE plpgsql;

CREATE TRIGGER rider_capacity_trigger
    AFTER INSERT OR UPDATE OR DELETE ON routes
    FOR EACH ROW
    EXECUTE FUNCTION update_rider_capacity();

-- Sync queue cleanup trigger
CREATE OR REPLACE FUNCTION set_sync_queue_cleanup()
RETURNS TRIGGER AS $
BEGIN
    IF NEW.status = 'completed' AND NEW.auto_cleanup_at IS NULL THEN
        NEW.auto_cleanup_at = NOW() + INTERVAL '24 hours';
    END IF;
    RETURN NEW;
END;
$ LANGUAGE plpgsql;

CREATE TRIGGER sync_queue_cleanup_trigger
    BEFORE UPDATE ON sync_queue
    FOR EACH ROW
    EXECUTE FUNCTION set_sync_queue_cleanup();

-- =========================================
-- USEFUL FUNCTIONS
-- =========================================

-- Generate unique order reference number
CREATE OR REPLACE FUNCTION generate_order_reference()
RETURNS VARCHAR(20) AS $
DECLARE
    ref_number VARCHAR(20);
    exists_check BOOLEAN;
BEGIN
    LOOP
        ref_number := 'ORD' || TO_CHAR(NOW(), 'YYYYMMDD') || LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0');
        
        SELECT EXISTS(SELECT 1 FROM orders WHERE reference_number = ref_number) INTO exists_check;
        
        IF NOT exists_check THEN
            EXIT;
        END IF;
    END LOOP;
    
    RETURN ref_number;
END;
$ LANGUAGE plpgsql;

-- Calculate distance between two points
CREATE OR REPLACE FUNCTION calculate_distance_km(
    point1 GEOGRAPHY,
    point2 GEOGRAPHY
) RETURNS DECIMAL(8,2) AS $
BEGIN
    RETURN (ST_Distance(point1, point2) / 1000)::DECIMAL(8,2);
END;
$ LANGUAGE plpgsql;

-- Check if point is within delivery zone
CREATE OR REPLACE FUNCTION is_location_serviceable(
    check_location GEOGRAPHY,
    hub_id_param UUID
) RETURNS BOOLEAN AS $
DECLARE
    zone_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO zone_count
    FROM hub_delivery_zones
    WHERE hub_id = hub_id_param
    AND is_active = true
    AND ST_Within(check_location, boundary);
    
    RETURN zone_count > 0;
END;
$ LANGUAGE plpgsql;

-- Get optimal hub for location
CREATE OR REPLACE FUNCTION get_optimal_hub(
    delivery_location GEOGRAPHY,
    tenant_id_param UUID
) RETURNS UUID AS $
DECLARE
    optimal_hub_id UUID;
BEGIN
    SELECT h.id INTO optimal_hub_id
    FROM hubs h
    JOIN hub_delivery_zones hdz ON h.id = hdz.hub_id
    WHERE h.tenant_id = tenant_id_param
    AND h.status = 'active'
    AND hdz.is_active = true
    AND ST_Within(delivery_location, hdz.boundary)
    ORDER BY hdz.priority ASC, ST_Distance(h.location, delivery_location) ASC
    LIMIT 1;
    
    RETURN optimal_hub_id;
END;
$ LANGUAGE plpgsql;

-- =========================================
-- VIEWS FOR COMMON QUERIES
-- =========================================

-- Active riders with current status
CREATE VIEW active_riders AS
SELECT 
    r.*,
    h.name as hub_name,
    t.name as tenant_name,
    COALESCE(rg.name, 'Unassigned') as group_name
FROM riders r
JOIN hubs h ON r.hub_id = h.id
JOIN tenants t ON r.tenant_id = t.id
LEFT JOIN rider_groups rg ON r.rider_group_id = rg.id
WHERE r.account_status = 'active';

-- Order summary with customer and rider info
CREATE VIEW order_summary AS
SELECT 
    o.*,
    c.first_name || ' ' || c.last_name as customer_full_name,
    c.email as customer_email_verified,
    r.first_name || ' ' || r.last_name as rider_full_name,
    r.phone as rider_phone,
    h.name as hub_name,
    t.name as tenant_name
FROM orders o
LEFT JOIN customers c ON o.customer_id = c.id
LEFT JOIN riders r ON o.rider_id = r.id
JOIN hubs h ON o.hub_id = h.id
JOIN tenants t ON o.tenant_id = t.id;

-- Current route status for dashboard
CREATE VIEW route_dashboard AS
SELECT 
    r.*,
    h.name as hub_name,
    t.name as tenant_name,
    rider.first_name || ' ' || rider.last_name as rider_name,
    rider.status as rider_status,
    COUNT(rs.id) as total_stops,
    COUNT(CASE WHEN rs.status = 'completed' THEN 1 END) as completed_stops
FROM routes r
JOIN hubs h ON r.hub_id = h.id
JOIN tenants t ON r.tenant_id = t.id
LEFT JOIN riders rider ON r.rider_id = rider.id
LEFT JOIN route_stops rs ON r.id = rs.route_id
GROUP BY r.id, h.name, t.name, rider.first_name, rider.last_name, rider.status;

-- =========================================
-- SAMPLE DATA CONSTRAINTS & VALIDATIONS
-- =========================================

-- Ensure order totals are consistent
ALTER TABLE orders ADD CONSTRAINT orders_total_check 
CHECK (total_amount >= 0 AND total_amount = COALESCE(subtotal, 0) + COALESCE(tax_amount, 0) + COALESCE(delivery_fee, 0) + COALESCE(tip_amount, 0));

-- Ensure rider capacity is valid
ALTER TABLE riders ADD CONSTRAINT riders_capacity_check 
CHECK (current_capacity_used >= 0 AND current_capacity_used <= vehicle_capacity);

-- Ensure rating is valid
ALTER TABLE riders ADD CONSTRAINT riders_rating_check 
CHECK (rating >= 1.0 AND rating <= 5.0);

-- Ensure efficiency score is positive
ALTER TABLE riders ADD CONSTRAINT riders_efficiency_check 
CHECK (efficiency_score > 0);

-- Ensure route stops sequence is valid
ALTER TABLE route_stops ADD CONSTRAINT route_stops_sequence_check 
CHECK (stop_sequence > 0);

-- Ensure sync queue priority is valid
ALTER TABLE sync_queue ADD CONSTRAINT sync_queue_priority_check 
CHECK (priority >= 1 AND priority <= 5);

-- Ensure payment amounts are positive
ALTER TABLE payment_transactions ADD CONSTRAINT payment_amount_check 
CHECK (amount > 0);

ALTER TABLE cod_collections ADD CONSTRAINT cod_amount_check 
CHECK (amount_collected > 0);

-- =========================================
-- COMMENTS FOR DOCUMENTATION
-- =========================================

COMMENT ON TABLE customers IS 'Platform-level customers who can order from any tenant through the unified app';
COMMENT ON TABLE users IS 'Employee users (admins, dispatchers) with tenant-specific access';
COMMENT ON TABLE riders IS 'Field workers/delivery personnel with operational data and mobile app integration';
COMMENT ON TABLE customer_addresses IS 'Customer delivery addresses without tenant isolation - global addresses';
COMMENT ON TABLE orders IS 'Master order table supporting all service types with hub transfer capabilities';
COMMENT ON TABLE riders IS 'Separated from users table for mobile app optimization and operational data';
COMMENT ON TABLE sync_queue IS 'Priority-based offline sync queue for React Native rider app';
COMMENT ON TABLE order_route_tracking IS 'GPS route tracking with street-level analytics and customer sharing';

-- =========================================
-- SCHEMA VERSION AND COMPLETION
-- =========================================

COMMENT ON SCHEMA public IS 'Airship Lite Database Schema v2.0 - Updated with separated customers and riders tables';

-- Schema is now complete and ready for production deployment