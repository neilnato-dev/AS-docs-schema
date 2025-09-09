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

*These decisions provide the foundation for implementing merchant functionality with minimal complexity while supporting all identified requirements.*