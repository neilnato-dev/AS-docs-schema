# Airship Lite - Platform Architecture

*For technical details on database design and implementation, see [AIRSHIP_TECHNICAL_IMPLEMENTATION.md](AIRSHIP_TECHNICAL_IMPLEMENTATION.md)*
*For business context and market strategy, see [AIRSHIP_BUSINESS_OVERVIEW.md](AIRSHIP_BUSINESS_OVERVIEW.md)*

## 4-Application Ecosystem

### **1. Admin Dashboard** (Web Application)

#### **Primary Users**
- Business owners and operators
- Dispatchers and operations managers
- Super admins with multi-hub access
- Hub-specific administrators

#### **Core Functionality**

**Central Command Center:**
- **Real-time Operations Dashboard:** View active orders, rider locations, and system metrics
- **Multi-hub Management:** Switch between locations or view consolidated operations
- **Live Order Monitoring:** Track order progression from placement to completion across all service types

**Order & Delivery Management:**
- **Universal Order Processing:** Handle all service types (pickup/delivery, food, shopping, errands, transportation) in unified interface
- **Service-Specific Workflows:** Customize order handling based on service type requirements
- **Order Creation:** Manual order entry for phone/walk-in customers
- **Order Modification:** Edit orders before rider assignment, handle cancellations and changes

**Smart Dispatching System:**
- **Manual Assignment:** Select specific riders for orders based on location, capacity, and skills
- **Automated Assignment:** AI-powered rider selection using location, availability, and performance metrics
- **Bulk Assignment:** Create routes with multiple stops assigned to single riders
- **Emergency Prioritization:** Handle urgent orders with priority assignment and route interruption

**Route Planning & Optimization:**
- **Route Creation:** Build efficient multi-stop routes manually or automatically
- **Optimization Engine:** Calculate optimal stop sequences considering distance, traffic, and time windows
- **Route Modification:** Add, remove, or reorder stops with automatic re-optimization
- **Route Monitoring:** Track route progress and rider adherence to planned sequences

**Service Configuration:**
- **Module Management:** Enable/disable service types (food delivery, shopping, errands, transportation)
- **Service Settings:** Configure pricing, availability, and operational parameters per service type
- **Hub Configuration:** Set delivery zones, operating hours, and service coverage areas
- **Pricing Rules:** Establish flat rates or distance-based pricing with time-based schedules

**Business Intelligence:**
- **Performance Analytics:** Track delivery times, completion rates, and operational efficiency
- **Financial Reporting:** Monitor revenue, rider earnings, and service profitability
- **Customer Insights:** Analyze order patterns, satisfaction ratings, and retention metrics
- **Rider Management:** View performance metrics, work schedules, and capacity utilization

#### **User Role Management**

**Super Admin:**
- Access to all hubs within tenant
- System configuration and user management
- Financial reporting and analytics across all locations
- Service module activation and pricing configuration

**Hub Admin:**
- Single hub access and management
- Order dispatch and rider coordination
- Hub-specific reporting and analytics
- Local service configuration within global constraints

**Dispatcher:**
- Order assignment and route creation
- Real-time monitoring and communication
- Limited configuration access
- Hub-specific operational focus

### **2. Riders App** (iOS/Android - React Native)

#### **Primary Users**
- Delivery riders and drivers
- Service personnel handling errands
- Transportation drivers for ride-hailing service

#### **Core Functionality**

**Task Management:**
- **Assignment Reception:** Receive push notifications for new task assignments
- **Task Review:** View detailed order information including service type, locations, and requirements
- **Accept/Reject System:** Choose assignments based on availability and preferences
- **Route Visualization:** See optimized route with all stops and navigation guidance

**Navigation & Route Guidance:**
- **Turn-by-Turn Navigation:** Integrated GPS navigation with real-time traffic updates
- **Route Optimization:** Follow system-calculated optimal sequences or override manually
- **Location Sharing:** Real-time location broadcasting to admin dashboard and customers
- **Geofencing Alerts:** Automatic notifications when arriving at pickup/delivery locations

**Service Execution:**
- **Pickup Confirmation:** Verify item collection with photo proof and item descriptions
- **Delivery Completion:** Confirm delivery with customer signatures, photos, and payment collection
- **Service-Specific Actions:** Food temperature maintenance, shopping receipt verification, errand task completion
- **Customer Communication:** Direct messaging and calling capabilities

**Proof of Delivery:**
- **Photo Capture:** High-quality images of delivered items and completion proof
- **Signature Collection:** Digital signature capture for delivery confirmation
- **Payment Processing:** COD collection with amount verification and confirmation
- **Document Upload:** Receipt photos, completion certificates, and task evidence

**Performance Tracking:**
- **Earnings Monitoring:** Real-time tracking of completed deliveries and earnings
- **Performance Metrics:** Delivery times, customer ratings, and efficiency scores
- **Work Schedule Management:** View assigned shifts and capacity utilization
- **Rating System:** Receive customer feedback and service quality ratings

#### **Offline-First Architecture**
- **Local Data Storage:** SQLite database for offline operation capability
- **Sync Queue System:** Priority-based synchronization with automatic retry
- **Network Recovery:** Robust handling of connectivity issues with data preservation
- **Critical Operation Priority:** Financial transactions and task completion given highest sync priority

### **3. Customer App** (Progressive Web App)

#### **Primary Users**
- End customers needing pickup and delivery services
- Business customers placing regular orders
- Individual consumers using various service types

#### **Core Functionality**

**Service Booking:**
- **Default Service:** Pickup and delivery service prominently featured
- **Service Selection:** Access to enabled service modules (food, shopping, errands, transportation)
- **Location Input:** GPS-based, search, or manual address entry for pickup and delivery points
- **Item Description:** Detailed descriptions for pickup/delivery items with special handling requirements

**Order Management:**
- **Order Placement:** Complete booking workflow with address, payment, and confirmation
- **Order Tracking:** Real-time progress monitoring with rider location sharing
- **Order History:** Complete record of past orders across all service types
- **Order Modification:** Limited changes before rider assignment

**Real-Time Tracking:**
- **Live Map View:** See rider location and estimated arrival times
- **Progress Updates:** Status notifications throughout order lifecycle
- **Route Sharing:** View planned delivery route and stops
- **Delivery Confirmation:** Receive proof of delivery with photos and signatures

**Payment Management:**
- **Payment Methods:** COD, GCash, and card processing options
- **Payment Consistency:** Selected payment method locked after order confirmation
- **Transaction History:** Complete record of payments and receipts
- **Price Transparency:** Clear pricing breakdown with delivery fees and service charges

**Communication:**
- **Rider Communication:** Direct messaging and calling capabilities
- **Admin Support:** Customer service chat and support requests
- **Notification Management:** Customizable alerts for order updates and promotions

#### **Service-Specific Features**

**Food Delivery:**
- Restaurant browsing with menus and ratings
- Item customization and cart management
- Order tracking from restaurant preparation through delivery

**Shopping Services:**
- Store selection and shopping list creation
- Budget setting and purchase approval
- Receipt verification and expense tracking

**Errand Services:**
- Task description and requirement specification
- Deadline setting and priority handling
- Progress updates and completion confirmation

**Transportation:**
- Pickup and destination setting
- Vehicle type selection based on passenger count
- Trip tracking and fare calculation

### **4. Merchant App** (Mobile Application)

#### **Primary Users**
- Restaurant owners and kitchen staff
- Store owners and retail personnel  
- Pharmacy and grocery managers
- Any business receiving orders through the platform

#### **Core Functionality**

**Order Reception:**
- **Real-Time Notifications:** Immediate alerts for new incoming orders
- **Order Details:** Complete order information including customer details, items, and special instructions
- **Service Integration:** Seamless reception of orders from Customer App or Admin Dashboard
- **Multi-Platform Access:** Receive orders regardless of originating platform

**Order Processing Workflow:**
- **Order Review:** Examine order details, availability, and preparation requirements
- **Order Confirmation:** Accept orders and confirm preparation timeline
- **Order Rejection:** Decline orders with reason codes (out of stock, closed, capacity)
- **Preparation Management:** Track order preparation progress and completion

**Status Management:**
- **Three-Status System:**
  - **New:** Freshly received orders awaiting merchant review
  - **Confirmed:** Accepted orders currently being prepared
  - **For Pickup:** Completed orders ready for rider collection
- **Status Updates:** Real-time synchronization with admin dashboard and rider app
- **Preparation Time:** Estimate and communicate order readiness timing

**Communication:**
- **Order Clarification:** Direct communication with customers for order questions
- **Rider Coordination:** Notify riders when orders are ready for pickup
- **Admin Updates:** Communicate delays, issues, or inventory problems

#### **Service-Specific Features**

**Food Service Integration:**
- Menu item availability management
- Kitchen preparation time estimation
- Special dietary requirement handling
- Order modification and substitution management

**Shopping Service Integration:**
- Product availability verification
- Price confirmation and updates
- Inventory status communication
- Receipt generation and verification

---

## Service Integration Patterns

### **Unified Data Flow Architecture**

#### **Service Routing Logic**

**Direct-to-Admin Services:**
```
Customer App → Admin Dashboard → Rider Assignment → Service Execution
```
- **Pickup & Delivery:** Point-to-point item transportation
- **Errands (Pasuyo):** Task completion services
- **Transportation:** Passenger ride services

**Merchant-Mediated Services:**
```
Customer App → Merchant App → Admin Dashboard → Rider Assignment → Service Execution
```
- **Food Delivery:** Restaurant order preparation required
- **Shopping Services (Pabili):** Store order confirmation needed

#### **Order Processing Workflow**

**Phase 1: Order Creation**
1. Customer selects service type and enters order details
2. System determines routing based on service type
3. Order validation including address verification and pricing calculation
4. Payment method selection and order confirmation

**Phase 2: Service-Specific Processing**

**For Direct Services:**
- Order immediately enters admin dashboard queue
- Automatic or manual rider assignment based on configuration
- Route optimization if multiple stops involved

**For Merchant-Mediated Services:**
- Order sent to relevant merchant app
- Merchant reviews and confirms/rejects order
- Confirmed orders enter admin dashboard for rider assignment
- Rejected orders returned to customer with notification

**Phase 3: Execution and Completion**
- Rider receives assignment with service-specific instructions
- Service execution following service type requirements
- Proof collection appropriate to service type
- Order completion and payment processing
- Status updates to all relevant parties

### **Cross-Platform Communication**

#### **Real-Time Updates**
- **Socket.io Integration:** 31K concurrent connection support
- **Event Broadcasting:** Status changes propagated to all relevant applications
- **Selective Updates:** Users receive only relevant notifications based on role and involvement

#### **Data Synchronization**
- **Master Data Management:** Admin dashboard maintains authoritative order and user data
- **Mobile Sync:** Priority-based offline queue with intelligent conflict resolution
- **Merchant Integration:** Real-time inventory and availability synchronization

---

## User Roles & Permissions

### **Multi-Tenant Isolation**

#### **Tenant-Level Separation**
- **Complete Data Isolation:** Each tenant's data completely separated using Row Level Security
- **Independent Configuration:** Service modules, pricing, and operational settings per tenant
- **Separate User Bases:** Customers, riders, and merchants belong to specific tenants
- **Cross-Tenant Prevention:** No data sharing or user access across tenant boundaries

#### **Hub-Based Operations**
- **Hub Assignment:** Users (admins, dispatchers, riders) assigned to specific hubs
- **Hub Isolation:** Riders cannot work across hubs within same tenant
- **Multi-Hub Access:** Super admins can access multiple hubs within their tenant
- **Zone Management:** Delivery zones defined per hub with overlap resolution

### **Role-Based Access Control**

#### **Admin Dashboard Roles**

**Super Admin:**
- **Scope:** All hubs within tenant
- **Permissions:** Full system configuration, user management, financial oversight
- **Capabilities:** Service module activation, pricing configuration, multi-hub analytics
- **Restrictions:** Cannot access other tenants' data

**Hub Admin:**
- **Scope:** Single hub within tenant
- **Permissions:** Hub operations management, local user administration
- **Capabilities:** Order dispatch, rider management, hub-specific reporting
- **Restrictions:** Cannot modify global tenant settings or access other hubs

**Dispatcher:**
- **Scope:** Single hub, operational focus
- **Permissions:** Order assignment, route creation, rider communication
- **Capabilities:** Real-time monitoring, manual dispatch, route optimization
- **Restrictions:** No user management or system configuration access

#### **Mobile App Roles**

**Rider:**
- **Scope:** Own profile and assigned orders
- **Permissions:** Task acceptance/rejection, location sharing, proof submission
- **Capabilities:** Route navigation, customer communication, earnings tracking
- **Restrictions:** Cannot see other riders' data or system-wide information

**Customer:**
- **Scope:** Own orders and profile
- **Permissions:** Order placement, tracking, payment, rating
- **Capabilities:** Service booking, real-time tracking, order history access
- **Restrictions:** No access to operational data or other customers' information

**Merchant:**
- **Scope:** Own orders and menu/inventory
- **Permissions:** Order confirmation/rejection, preparation status updates
- **Capabilities:** Order management, inventory updates, rider communication
- **Restrictions:** Cannot access other merchants' data or system operations

---

## Geographic & Multi-Hub Operations

### **Hub and Spoke Model**

#### **Hub Definition and Management**
- **Physical Locations:** Each hub represents actual business location/branch
- **Service Coverage:** Hub-specific delivery zones with polygon boundaries
- **Operational Independence:** Each hub operates independently with separate staff and inventory
- **Unified Oversight:** Super admins can view consolidated operations across hubs

#### **Delivery Zone Management**
- **Polygon-Based Zones:** Custom-drawn delivery boundaries for each hub
- **Zone Overlap Handling:** Multiple hubs can serve same area with priority-based assignment
- **Priority Resolution:**
  1. Identify all hubs serving customer location
  2. Select hub with highest priority (1=highest priority)
  3. If equal priority, choose hub with available riders
  4. If no riders available, queue until capacity becomes available

#### **Inter-Hub Operations**
- **Hub Transfers:** Supported for pickup/delivery service only
- **Transfer Process:** Multi-hop transfers possible (Hub A → Hub B → Hub C)
- **Transfer Tracking:** Complete audit trail with sequence numbers and status updates
- **Transfer Coordination:** Automated notification and coordination between hubs

### **Route Optimization & Management**

#### **Route Creation Methods**
- **Manual Creation:** Dispatchers build routes with specific stop sequences
- **Automated Generation:** System creates optimized routes based on order proximity and timing
- **Hybrid Approach:** Manual route framework with automatic optimization

#### **Route Optimization Factors**
- **Distance Weight:** Minimize total distance traveled
- **Time Weight:** Optimize for shortest total time including traffic
- **Rider Efficiency:** Factor in individual rider performance and speed
- **Customer Windows:** Respect delivery time preferences and requirements
- **Capacity Utilization:** Maximize rider capacity usage while respecting limits

#### **Route Execution and Flexibility**
- **Sequence Compliance:** Riders encouraged to follow optimized sequence
- **Manual Override:** Riders can deviate from planned sequence when necessary
- **Automatic Re-optimization:** System recalculates route when deviations occur
- **Emergency Insertion:** High-priority orders can interrupt and modify existing routes

### **Multi-Location Scaling**

#### **Tenant Expansion Support**
- **Multi-City Operations:** Single tenant account managing multiple cities
- **Regional Coordination:** Consolidated reporting and management across locations
- **Local Adaptation:** Hub-specific pricing, services, and operational parameters
- **Centralized Control:** Unified admin access with location-specific operational control

#### **Geographic Expansion Framework**
- **Timezone Management:** Automatic handling of multiple timezones within single tenant
- **Local Settings:** Currency, language, and cultural adaptation per region
- **Address Flexibility:** Pin-based location system independent of local address formats
- **Distance Calculations:** Geographic-aware routing accounting for terrain and infrastructure

---

## Integration Architecture

### **API-First Design**

#### **Service Integration APIs**
- **Order Management API:** Universal order processing across all service types
- **Rider Management API:** Assignment, tracking, and performance management
- **Real-Time Updates API:** Status changes and location updates
- **Analytics API:** Reporting and business intelligence data access

#### **Third-Party Integration Framework**
- **Payment Gateway Integration:** Multiple payment processors with tokenization
- **Mapping Service Integration:** Google Maps and Mapbox for routing and optimization
- **SMS/Communication Integration:** Multi-provider SMS and push notification services
- **Route Optimization Integration:** External algorithm providers with standardized interfaces

### **Real-Time Communication**

#### **Socket.io Implementation**
- **Connection Management:** Support for 31K concurrent connections
- **Event Types:** Order updates, rider locations, system notifications, emergency alerts
- **Selective Broadcasting:** Targeted updates based on user roles and involvement
- **Connection Recovery:** Robust reconnection and state synchronization

#### **Mobile-First Architecture**
- **Progressive Web App:** Universal access without app store dependencies
- **Offline Capability:** Local data storage and sync queue management
- **Network Optimization:** Efficient data usage and background synchronization
- **Cross-Platform Consistency:** Unified experience across devices and platforms

---

## Work Schedule & Capacity Management Integration

### **Rider Work Schedule System**

#### **Schedule Structure Implementation**
- **Daily Shifts:** Configurable start/end times with maximum duration limits per shift
- **Break Requirements:** Mandatory break periods based on shift length (e.g., 30min break for 8+ hour shifts)
- **Shift Limits:** Maximum consecutive working days and required rest periods
- **Schedule Flexibility:** Weekly recurring schedules with individual day override capabilities

#### **Route Duration Integration**
- **Schedule Validation:** Routes automatically validated against rider available work hours
- **Duration Limits:** Route assignments respect rider work schedule limits and break requirements
- **Overtime Management:** Optional overtime assignment with premium rate calculations
- **Shift Boundary Handling:** Routes cannot extend beyond rider scheduled work hours

#### **Efficiency Factor Integration**
- **Performance Scoring:** Rider efficiency score affects route optimization calculations (1.0 = average, 1.5 = 50% better performance)
- **Dynamic Assignment:** Higher efficiency riders receive priority for complex or time-sensitive routes
- **Capacity Calculations:** Efficiency factor influences maximum order capacity per rider
- **Performance Tracking:** Historical efficiency data used for future assignment optimization

### **Emergency Order Workflow Integration**

#### **Priority-Based Route Interruption**
- **Emergency Detection:** Orders marked with `priority = 'emergency'` and `can_interrupt_routes = true`
- **Route Analysis:** System identifies in-progress routes within 5km radius of emergency pickup location
- **Impact Assessment:** Calculates estimated delay to existing routes (typically 15 minutes per affected route)
- **Rider Notification:** Affected riders receive immediate notification of route modification with new stop insertion

#### **Capacity Override Management**
- **Emergency Bypass:** Emergency orders marked with `capacity_override = true` can exceed normal rider capacity
- **Risk Assessment:** System tracks capacity overrides and monitors completion success rates
- **Performance Impact:** Capacity overrides analyzed for impact on delivery times and rider efficiency
- **Automatic Rebalancing:** System automatically redistributes normal-priority orders when capacity limits exceeded

### **Pricing Schedule Implementation**

#### **Time-Based Pricing Activation**
- **Hub-Specific Scheduling:** Pricing schedules configured per hub, not tenant-wide, allowing location-specific pricing strategies
- **Day and Time Specification:** Custom time ranges with specific day-of-week targeting (e.g., Friday 7pm-11pm)
- **Multiplier Application:** Pricing schedules apply multipliers to base pricing rules rather than replacing them
- **Single Schedule Rule:** Only one pricing schedule can be active per time period to prevent conflicting rates

#### **Pricing Calculation Integration**
```
Final Price = Base Pricing Rule × Active Schedule Multiplier
```
- **Schedule Priority:** When multiple schedules could apply, system selects based on creation date (newer takes precedence)
- **Real-Time Application:** Pricing changes apply immediately to new orders, existing orders maintain original pricing
- **Schedule Validation:** System prevents overlapping time schedules within same hub
- **Performance Optimization:** Pricing calculations cached for frequently accessed routes and time periods

### **Service-Specific Workflow Enhancements**

#### **Food Delivery Integration**
- **Preparation Time Scheduling:** Restaurant preparation times integrated with rider work schedules to optimize pickup timing
- **Temperature Requirements:** Routes prioritize food deliveries to minimize transit time and maintain food quality
- **Kitchen Coordination:** Rider assignments coordinated with restaurant preparation schedules to minimize wait times

#### **Shopping Service Coordination**
- **Shopping Time Allocation:** Rider schedules account for shopping time at stores (typically 15-30 minutes per shopping order)
- **Payment Capability:** Shopping orders assigned only to riders with payment processing capabilities and sufficient advance funds
- **Receipt Management:** Shopping orders include additional time for receipt photography and customer verification

#### **Transportation Service Integration**
- **Passenger Scheduling:** Transportation orders respect rider vehicle type and passenger capacity constraints
- **Route Prioritization:** Passenger transportation receives priority over package delivery when combined in single route
- **Vehicle Requirements:** Transportation orders automatically filtered by rider vehicle type (motorcycle, car, van)

This comprehensive platform architecture provides detailed operational frameworks for integrating work schedules, emergency procedures, and pricing strategies across all service types while maintaining efficient multi-tenant operations.