# Airship Lite Platform Overview

## What is Airship Lite?

Airship Lite is a **last-mile delivery management platform** designed to streamline pickup and delivery operations for businesses of all sizes. The core system focuses on **point-to-point delivery services**, connecting customers who need items transported with professional delivery riders and efficient dispatch management.

### Core Value Proposition

**Complete last-mile delivery solution** with order placement, intelligent dispatching, real-time tracking, and seamless pickup-to-delivery experience. The platform's **pickup and delivery service is the foundation**, with additional service modules (food delivery, shopping, errands, transportation) available as **configurable add-ons** that can be enabled through the admin dashboard.

---

## Platform Architecture

Airship Lite consists of **three interconnected applications**:

### 1. **Admin Dashboard** (Web Application)

**Primary Users:** Business owners, dispatchers, operations managers, and administrators

**What it does:**

- **Central Command Center** for managing the entire delivery operation
- **Order & Delivery Management** with complete CRUD operations and status tracking
- **Smart Dispatching System** with both manual and AI-powered assignment
- **Route Planning & Optimization** for efficient delivery management
- **Real-time Monitoring** of riders, orders, and operational metrics
- **Service Module Configuration** - Enable/disable additional services (Food Delivery, Shopping, Errands, Transportation)
- **Add-on Management** - Configure service-specific settings, pricing, and operational parameters
- **Business Intelligence** with analytics, reporting, and performance insights

### 2. **Riders Mobile App** (iOS/Android)

**Primary Users:** Delivery riders, drivers, and service personnel

**What it does:**

- **Task Management** for accepting, viewing, and managing delivery assignments
- **Navigation & Route Guidance** with turn-by-turn directions and optimization
- **Proof of Delivery** with photo capture, signatures, and payment collection
- **Real-time Communication** with customers and dispatchers
- **Performance Tracking** with earnings, ratings, and delivery metrics

### 3. **Client App/Site** (Progressive Web App)

**Primary Users:** End customers and businesses needing pickup and delivery services

**What it does:**

- **Primary Function:** Book pickup and delivery services for item transportation
- **Core Service:** Point-to-point delivery with item descriptions, pickup/delivery addresses
- **Optional Modules:** Additional services (food delivery, shopping, errands, transportation) when enabled by admin
- **Real-time Tracking** of orders and rider location
- **Payment Management** with multiple payment options
- **Order History** and transaction records

---

## Service-Specific User Flows

### **1. Pickup & Delivery Service Flow (Default)**

```
Customer Request → Item Description → Pickup Details → Delivery Details → Order Confirmation → Rider Assignment → Pickup Execution → Delivery Completion
```

**Brief Process:**

1. **Order Creation:** Customer describes items, sets pickup and delivery locations
2. **Admin Processing:** Order appears in dashboard, gets assigned to available rider
3. **Rider Pickup:** Rider navigates to pickup location, confirms item collection
4. **Delivery Execution:** Rider transports items to delivery address, obtains proof of delivery
5. **Completion:** Payment processed, delivery confirmed, order closed

### **2. Food Delivery Service Flow**

```
Browse Restaurants → Select Menu Items → Add to Cart → Checkout → Restaurant Preparation → Rider Pickup → Food Delivery
```

**Brief Process:**

1. **Restaurant Selection:** Customer browses available restaurants and menus
2. **Order Placement:** Selects food items, adds special instructions, confirms order
3. **Restaurant Processing:** Kitchen receives order, prepares food, notifies when ready
4. **Rider Assignment:** Available rider assigned for pickup from restaurant
5. **Food Transport:** Rider collects prepared order, delivers to customer with thermal bags
6. **Completion:** Customer receives food, confirms delivery, provides rating

### **3. Shopping Service Flow (Pabili)**

```
Shopping Request → Store Selection → Shopping List → Budget Approval → Rider Shopping → Item Verification → Delivery
```

**Brief Process:**

1. **Shopping Request:** Customer specifies store and creates detailed shopping list
2. **Budget Setting:** Establishes spending limit and payment method for purchases
3. **Rider Assignment:** Qualified rider assigned with shopping experience and payment capability
4. **Shopping Execution:** Rider visits store, purchases items per list, sends receipt photos
5. **Customer Verification:** Customer approves purchases and total amount via app
6. **Delivery Completion:** Rider delivers purchased items with receipts and change

### **4. Errand Service Flow (Pasuyo)**

```
Task Description → Errand Details → Document Preparation → Rider Assignment → Task Execution → Proof Submission
```

**Brief Process:**

1. **Task Request:** Customer describes errand (bill payment, document submission, etc.)
2. **Detail Specification:** Provides location, requirements, deadlines, and necessary documents
3. **Rider Briefing:** Experienced rider assigned with clear instructions and required items
4. **Errand Execution:** Rider performs task at specified location (payment, queuing, submission)
5. **Proof Collection:** Photos of receipts, completed forms, or confirmation documents
6. **Task Completion:** Customer receives proof of completed errand and any returned items

### **5. Transportation Service Flow**

```
Ride Request → Vehicle Selection → Pickup Location → Destination Setting → Driver Assignment → Passenger Pickup → Trip Completion
```

**Brief Process:**

1. **Ride Booking:** Customer sets pickup location and destination with vehicle preference
2. **Driver Matching:** Available driver with suitable vehicle assigned based on proximity
3. **Pickup Coordination:** Driver navigates to customer location, confirms passenger identity
4. **Trip Execution:** Safe transport to destination following optimal route
5. **Payment Processing:** Automatic fare calculation, payment through app or cash
6. **Trip Closure:** Passenger dropped off, trip rated, driver available for next booking

---

## Complete End-to-End Flow: Client to Admin to Rider to Delivery

### **Overall System Flow (All Services)**

```
CLIENT APP → ADMIN DASHBOARD → RIDERS APP → SERVICE EXECUTION → COMPLETION → STATUS UPDATES
```

### **Detailed Cross-Platform Process:**

#### **Phase 1: Order Creation (Client App)**

**For Pickup & Delivery:**

```
Open App → Describe Items → Set Pickup Address → Set Delivery Address → Payment Method → Confirm Order
```

**For Food Delivery:**

```
Open App → Browse Restaurants → Select Menu Items → Add to Cart → Delivery Address → Payment → Order Confirmation
```

**For Shopping Services:**

```
Open App → Select Store → Create Shopping List → Set Budget → Delivery Address → Payment Method → Confirm Request
```

**For Errands:**

```
Open App → Describe Task → Specify Location → Upload Documents → Set Deadline → Payment Method → Submit Request
```

**For Transportation:**

```
Open App → Set Pickup Location → Enter Destination → Choose Vehicle Type → Confirm Booking → Wait for Driver
```

#### **Phase 2: Order Management (Admin Dashboard)**

```
Order Received → Validation & Pricing → Service-Specific Processing → Rider Assignment → Dispatch → Monitor Progress
```

**Common Process:**

1. **Order Visibility** - All orders appear in unified dashboard regardless of service type
2. **Service Classification** - System identifies service type and applies appropriate workflow
3. **Validation** - Addresses verified, pricing calculated, special requirements noted
4. **Rider Matching** - System matches orders with riders having appropriate skills/equipment
5. **Dispatch Optimization** - Route planning considers service type (food thermal bags, shopping payment, etc.)
6. **Live Monitoring** - Real-time tracking with service-specific status updates

#### **Phase 3: Task Execution (Riders App)**

**Core Process for All Services:**

```
Receive Task → Accept → Navigate → Execute Service → Collect Proof → Complete → Update Status
```

**Service-Specific Execution:**

- **Pickup & Delivery:** Collect items → Transport → Deliver with proof
- **Food Delivery:** Pickup from restaurant → Maintain temperature → Deliver fresh food
- **Shopping:** Visit store → Purchase items → Send receipt → Deliver with change
- **Errands:** Perform task → Document completion → Return items/receipts
- **Transportation:** Pickup passenger → Safe transport → Drop-off at destination

#### **Phase 4: Completion & Updates (System-wide)**

```
Service Completed → Proof Verified → Payment Processed → Customer Notified → Analytics Updated → Order Archived
```

**Universal Completion:**

1. **Service Confirmation** - Rider marks completion with appropriate proof
2. **Quality Check** - System verifies proof meets service requirements
3. **Payment Processing** - Service fees, rider earnings, and customer charges processed
4. **Notification Chain** - All parties receive completion confirmations
5. **Performance Analytics** - Service metrics updated across all dashboards
6. **Order Closure** - Completed order archived with full audit trail

---

## Service Categories & Target Markets

### **Core Service: Pickup & Delivery (Default)**

**Primary Function:** Point-to-point transportation of items, documents, packages, and parcels

- **Target Users:** Businesses needing courier services, individuals sending items
- **Use Cases:** Document delivery, package transport, parcel shipping, item transfers
- **Default Configuration:** Available immediately upon platform setup

### **Additional Service Modules (Configurable Add-ons)**

_These services can be enabled/disabled through Admin Dashboard configuration:_

### **Additional Service Modules (Configurable Add-ons)**

_These services can be enabled/disabled through Admin Dashboard configuration:_

#### 🍔 **Food Delivery Module**

**What it does:**

- **Restaurant Management:** Add/manage restaurant partners with menus, pricing, and availability
- **Menu Systems:** Create categories, items, descriptions, images, and real-time inventory
- **Order Processing:** Handle food orders with kitchen preparation times and delivery coordination
- **Multi-Restaurant Support:** Manage single locations, multi-branch chains, or restaurant groups
- **Specialized Features:** Operating hours, food categories, dietary options, delivery zones

**Target Users:** Restaurants, cloud kitchens, food courts, catering services, meal subscription businesses

#### 🛒 **Shopping Services Module (Pabili)**

**What it does:**

- **Personal Shopping:** Riders shop for customers at specified stores with detailed shopping lists
- **Store Integration:** Partner with groceries, pharmacies, retail stores for direct ordering
- **Product Catalog:** Browse store inventories when integrated, or custom shopping requests
- **Budget Management:** Set spending limits and get real-time purchase confirmations
- **Receipt Verification:** Photo proof of purchases and price confirmations before delivery

**Target Users:** Grocery stores, pharmacies, retail shops, supermarkets, convenience stores

#### 📋 **Errand Services Module (Pasuyo)**

**What it does:**

- **Bill Payments:** Utilities, credit cards, loans, government fees through partner locations
- **Document Services:** Government transactions, permit applications, document submissions
- **Custom Tasks:** Queueing services, form submissions, appointment bookings
- **Proof of Completion:** Photo documentation, receipts, and confirmation of task completion
- **Time-sensitive Errands:** Deadline management and priority handling

**Target Users:** Service centers, government offices, banks, professional service providers

#### 🚗 **Transportation Module**

**What it does:**

- **Ride Booking:** Point-to-point passenger transportation with various vehicle options
- **Vehicle Types:** Motorcycles, cars, vans, based on passenger count and distance
- **Route Planning:** Optimal routing for single or multiple passenger pickups
- **Fare Calculation:** Distance-based pricing with surge pricing during peak hours
- **Driver Management:** Background checks, vehicle verification, and performance tracking

**Target Users:** Transportation companies, motorcycle taxi operators, car rental services, ride-sharing fleets

---

## Key User Flows

### **Admin Dashboard Flow**

```
Login → Dashboard Overview → Order Management → Dispatch Assignment → Route Planning → Real-time Monitoring → Analytics & Reporting
```

**Detailed Process:**

1. **Login & Access** - Secure authentication with role-based permissions
2. **Dashboard Overview** - View real-time metrics (orders, riders, deliveries, revenue)
3. **Order Management** - Create, view, edit, and track all orders in centralized system
4. **Smart Dispatching** - Auto-assign or manually assign orders to optimal riders
5. **Route Optimization** - Create efficient multi-stop routes for maximum efficiency
6. **Live Monitoring** - Track rider locations, order statuses, and delivery progress
7. **Analytics** - Generate reports on performance, revenue, and operational insights

### **Rider App Flow**

```
Login → Set Online Status → Receive Task Notification → Accept/Reject → Navigate to Pickup → Collect Items → Navigate to Delivery → Proof of Delivery → Complete Task
```

**Detailed Process:**

1. **Authentication** - Login and set availability status (online/offline)
2. **Task Reception** - Receive push notifications for new delivery assignments
3. **Task Management** - Accept tasks and view detailed order information
4. **Navigation** - Follow optimized routes with turn-by-turn directions
5. **Pickup Process** - Arrive at pickup location, confirm item collection
6. **Delivery Process** - Navigate to delivery location with real-time tracking
7. **Proof of Delivery** - Capture photos, signatures, collect payments (COD)
8. **Task Completion** - Mark delivery complete and update status

### **Client App Flow (Primary: Pickup & Delivery)**

```
Open App → Default Pickup & Delivery Screen → Enter Item Description → Set Pickup Address → Set Delivery Address → Select Payment → Confirm Order → Track Progress
```

**Detailed Process:**

1. **App Access** - Client app opens directly to pickup & delivery service (default)
2. **Order Creation** - Describe items, set pickup location and delivery destination
3. **Address Input** - Use GPS, search, or manual entry for accurate locations
4. **Pricing Display** - Auto-calculated delivery fee based on distance and item type
5. **Payment Method** - Select from available options (COD is default)
6. **Order Confirmation** - Review details and submit order to system
7. **Real-time Tracking** - Monitor order progress and rider location
8. **Delivery Confirmation** - Receive notification when delivery is completed

_Note: Additional service modules (Food, Shopping, Errands, Transportation) appear only when enabled by admin and configured for the specific client deployment._

---

## Advanced Features

### **AI-Powered Intelligence**

- **Smart Order Allocation** based on rider location, availability, capacity, and performance
- **Advanced Route Optimization** considering real-time traffic and delivery windows
- **Predictive ETA Calculations** with dynamic adjustments
- **Automated Dispatch** with intelligent rider assignment

### **Real-time Operations**

- **Live GPS Tracking** of all riders and deliveries
- **Geofencing Alerts** for pickup and delivery confirmations
- **Dynamic Route Adjustments** based on traffic and conditions
- **Instant Notifications** across all platforms

### **Business Intelligence**

- **Operational Analytics** - Delivery rates, completion times, rider performance
- **Financial Reporting** - Revenue tracking, payment collection, cost analysis
- **Customer Insights** - Order patterns, satisfaction ratings, retention metrics
- **Predictive Analytics** - Demand forecasting and capacity planning

---

## Target Market

### **Geographic Focus**

- **Primary:** Philippines (urban and suburban areas)
- **Expansion:** Southeast Asia region
- **Global Scaling** capability built into platform architecture

### **Primary Target Market**

#### **Businesses with Existing Fleet Operations**

- **E-commerce Companies** with their own delivery teams needing better dispatch management
- **Retail Chains** managing deliveries across multiple locations
- **Corporate Fleet Managers** coordinating company vehicles and drivers
- **Logistics Providers** seeking to modernize their operations with digital tools

#### **Food & Beverage Industry**

- **Restaurants** (single location, multi-branch chains, restaurant groups)
- **Cloud Kitchens** and virtual restaurant brands
- **Food Courts** and mall-based food vendors
- **Catering Services** and meal subscription businesses
- **Home-based Food Entrepreneurs**

#### **Retail & Commercial Establishments**

- **Local Shops** and neighborhood stores (sari-sari stores, convenience stores)
- **Specialty Retail** (clothing, electronics, furniture, flowers, gifts)
- **Pharmacies and Drugstores** (independent and chain pharmacies)
- **Grocery Stores** (supermarkets, wet markets, organic stores)
- **Department Stores** and shopping centers

#### **Service-Oriented Businesses**

- **Local Courier Companies** looking to digitize their operations
- **Traditional Delivery Services** transitioning from phone/SMS booking
- **Logistics Startups** needing ready-to-deploy delivery infrastructure
- **Professional Service Providers** requiring document and item transport

#### **Multi-Service Operators**

- **Businesses seeking to expand** their service offerings beyond their core business
- **Franchisees** wanting to offer multiple services under one platform
- **Service Aggregators** combining different business types in one operation

### **User Segments**

- **Primary B2B Clients:** Courier companies, e-commerce businesses, logistics providers
- **Primary B2C Customers:** Individuals and businesses needing pickup and delivery services
- **Service Providers:** Independent riders, drivers, and delivery personnel
- **Extended Markets:** Restaurants, retailers, service companies (when additional modules are enabled)

---

## Competitive Advantages

### **Multi-Service Integration**

Core pickup & delivery platform with **modular service expansion** - additional services can be enabled without rebuilding the system

### **Flexible Deployment**

- **Default Configuration:** Pickup & delivery service ready out-of-the-box
- **Modular Add-ons:** Enable food delivery, shopping, errands, or transportation as needed
- **White-label Customization** for business branding
- **Self-service Configuration** reducing onboarding friction

### **Advanced Technology**

- **AI-powered Dispatching** for optimal efficiency
- **Real-time Route Optimization** with traffic consideration
- **Progressive Web App** technology for universal accessibility

### **Product-Led Growth (PLG)**

- **Self-service Onboarding** without intensive support requirements
- **Usage-based Feature Unlocking** encouraging platform adoption
- **Trial Access** to demonstrate value before commitment

---

## Business Impact

### **For Business Owners**

- **Last-Mile Efficiency:** Streamlined pickup and delivery operations with intelligent dispatching
- **Cost Optimization:** Route optimization leading to fuel savings and better resource utilization
- **Customer Satisfaction:** Real-time tracking and reliable delivery estimates
- **Business Intelligence:** Data-driven insights for delivery performance improvements
- **Scalable Operations:** Handle increasing delivery volume without proportional staff increases

### **For Riders**

- **Increased Earnings:** Optimized routes allowing more deliveries per day
- **Better Work Management:** Clear task visibility and efficient route planning
- **Performance Tracking:** Transparent metrics and feedback systems
- **Flexible Operations:** Accept/reject tasks based on availability and preferences

### **For Customers**

- **Convenience:** Professional pickup and delivery service accessible through single platform
- **Transparency:** Real-time tracking and accurate delivery estimates
- **Reliability:** Proof of pickup and delivery with professional service standards
- **Flexibility:** Schedule immediate or future pickups with various delivery options

---

## Platform Scalability

### **Core System Architecture**

- **Last-Mile Delivery Foundation:** Robust pickup and delivery system as base platform
- **Modular Service Framework:** Additional services built as configurable modules
- **Multi-tenant SaaS Model** supporting multiple clients simultaneously
- **Cloud-based Infrastructure** for global scalability
- **API-first Design** enabling easy integrations and customizations
- **Progressive Web App** reducing platform-specific development needs

### **Business Scalability**

- **Rapid Deployment:** Quick setup for new markets and business types
- **Localization Support:** Multiple languages, currencies, and regional settings
- **Integration Capabilities:** POS systems, payment gateways, and third-party services
- **Flexible Pricing Models:** Subscription-based with usage scaling

This comprehensive platform represents the evolution of traditional courier and delivery services into a modern, intelligent, and scalable **last-mile delivery solution**. The **pickup and delivery core** provides immediate value, while **configurable service modules** allow businesses to expand into additional markets like food delivery, shopping services, errands, and transportation as their needs grow.
