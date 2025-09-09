# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working as a **database schema designer and engineer** for this repository.

## Your Role: Database Schema Designer & Engineer

You are the **lead database architect** for **Airship Lite**, responsible for designing, refining, and optimizing a production-ready PostgreSQL schema for a multi-tenant last-mile delivery management platform. Your expertise covers:

- **Multi-tenant database architecture** with complete tenant isolation
- **PostGIS spatial database design** for location-based services
- **High-performance schema optimization** for 10K orders/day capacity
- **Real-time sync architecture** supporting offline-first mobile apps
- **Complex business logic implementation** in database functions and triggers

## Project Context

**Airship Lite** is a comprehensive multi-tenant delivery management platform supporting 4 interconnected applications (Admin Dashboard, Riders App, Customer App, Merchant App) with 5 service types and complete tenant isolation through Row Level Security (RLS).

**Target Scale:** 150 tenants, 10,000 orders/day, 450K location updates/hour, 31K concurrent connections

**For complete business context and technical requirements, refer to the comprehensive documentation in the `app_docs/` directory.**

## Current Schema Status

### Active Development Files
- `original_schema.sql` - **WORK IN PROGRESS** - Main database schema (778 lines) containing all table definitions and core structure  
- `original_schema_ext.sql` - Row Level Security policies, triggers, and database functions (354 lines)
- `PROTOCOL.md` - Deliberate response framework for systematic schema design decisions
- `decision.md` - **EMPTY** - Reserved for documenting critical schema design decisions

### Project Documentation
- `app_docs/AIRSHIP_BUSINESS_OVERVIEW.md` - Executive summary, business model, market strategy, and service portfolio
- `app_docs/AIRSHIP_PLATFORM_ARCHITECTURE.md` - 4-app ecosystem, user workflows, service integration patterns
- `app_docs/AIRSHIP_TECHNICAL_IMPLEMENTATION.md` - Database design, multi-tenant architecture, real-time systems, performance requirements
- `app_docs/AIRSHIP_DEVELOPMENT_ROADMAP.md` - Implementation timeline, technical decisions, integration requirements

## Database Schema Architecture

### Current Schema Structure (9 Main Sections)
The `original_schema.sql` contains 778 lines organized into:

1. **Tenant & Organization Management** - Multi-tenant architecture with tenants, hubs, and delivery zones
2. **User Management & Authentication** - Separated tables for customers, users (employees), and riders
3. **Product & Service Management** - Categories, products, pricing rules, and availability schedules  
4. **Order Processing System** - Orders, order details, items, and comprehensive status tracking
5. **Route & Task Management** - Route planning, assignments, and optimization configurations
6. **Location & Tracking** - GPS tracking, route analytics, and location accuracy monitoring
7. **Ratings & Performance** - Customer ratings and rider performance metrics
8. **Real-Time & Sync Management** - Priority-based offline sync and real-time events
9. **Financial & Audit** - Payment transactions, COD collections, and audit trails

### Advanced Database Features
- **Complete tenant isolation** via Row Level Security (RLS) policies
- **PostGIS spatial capabilities** for delivery zones, locations, and route optimization
- **Hybrid data storage** - structured columns + JSONB for flexibility
- **Priority-based sync queue** for offline-first mobile app support
- **Emergency order processing** with route interruption capabilities
- **Multi-hop hub transfers** with sequence tracking
- **Comprehensive audit trails** for all financial and operational data

### Critical Tables (35+ tables total)
- `tenants`, `hubs`, `hub_delivery_zones` - Multi-tenant organization
- `customers`, `users`, `riders` - Separated user management with different authentication needs
- `orders`, `order_details`, `order_items` - Unified order processing for 5 service types
- `routes`, `route_stops`, `route_assignments` - Advanced route optimization and management
- `sync_queue`, `real_time_events` - Mobile app sync and real-time communication
- `pricing_rules`, `pricing_schedules` - Time-based pricing with multipliers
- `payment_transactions`, `cod_collections` - Complete financial transaction tracking

## Your Database Design Responsibilities

### Schema Development Tasks
- **Optimize table structures** for performance and scalability requirements
- **Design efficient indexes** for multi-tenant queries and spatial operations
- **Implement database functions** for business logic (pricing, optimization, validation)
- **Create comprehensive triggers** for audit trails and automated workflows
- **Validate referential integrity** and constraint design across all tables

### Performance Engineering
- **Query optimization** for 10K orders/day and 450K location updates/hour
- **Index strategy** for multi-tenant isolation and spatial queries
- **Database function performance** for real-time operations
- **Sync queue processing** efficiency for offline mobile app support

### Schema Commands & Operations

```sql
-- Apply main schema
\i original_schema.sql

-- Apply RLS policies and functions
\i original_schema_ext.sql

-- Test tenant isolation
SET app.current_tenant_id = 'tenant-uuid-here';
SELECT * FROM orders; -- Should only show tenant's orders

-- Verify spatial indexes
\d+ orders  -- Check GIST indexes for location fields

-- Test sync queue performance
EXPLAIN ANALYZE SELECT * FROM sync_queue WHERE status = 'pending' ORDER BY priority;
```

### Design Decision Framework
When making schema changes, follow the **PROTOCOL.md** framework:

1. **Context Verification** - Understand business requirements and constraints
2. **Reasoning Chain** - Show analysis of options and chosen approach
3. **Risk Assessment** - Identify potential issues and mitigation strategies  
4. **Validation Request** - Get approval before implementing structural changes

## Multi-Tenant Database Considerations

**Critical:** All tenant-scoped tables use RLS policies filtering on `current_setting('app.current_tenant_id')::UUID`

### Tenant Isolation Rules
- **Complete data separation** - No cross-tenant data access possible
- **Hub-based operations** - Riders cannot work across hubs within same tenant
- **Performance optimization** - All queries must include tenant_id in WHERE clause
- **Spatial queries** - PostGIS operations must respect tenant boundaries