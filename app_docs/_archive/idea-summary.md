# App Idea: Last Mile Delivery System

I have an app idea that involves a last mile delivery system, and it includes 4 applications: the admin dashboard, the riders app,customer app, and the merchant app.

## Admin Dashboard

Let's talk first about the admin dashboard. The admin dashboard is used by our direct clients. Our clients could be couriers, local deliveries, restaurants, pharmacies, groceries, retail, and basically any other businesses that include deliveries in their services or operations. That's the target of the admin dashboard.

## Riders App

For the riders app, this is used by the riders or drivers of our clients. They use this app for the tasks or deliveries that were dispatched to them by the admins or dispatchers on the admin dashboard. They use the riders app for navigation, for completing deliveries, and for capturing proof of delivery (POD) like signatures and images.

## Customer App

For the customer app, it's an application for the clients of our clients. They offer this to their clients, where they can book their deliveries from the customer app. Basically, that's the whole point of the idea and the app.

### Customer App Features

Let's dig more into the customer app. The customer app, by default, features a booking system that lets users book pickup or delivery, or both. It really depends on how the app will be used, or depending on the business model of our clients. But basically, it's pickup and delivery booking.

To add or expand the customer app, we want add-ons that are configurable in the admin dashboard. Since our clients vary from restaurants, couriers or delivery services, groceries, and others, there will be available service types like pickup and delivery service, food order service, errand service, transportation service, and shopping services. Those will be available on the customer app.

## Merchant App

The merchant app is used by partners of our clients. Merchants include restaurants, pharmacies, grocery and retail stores. The main purpose of the merchant app is to receive orders from the customer app or the admin dashboard. The merchant app is designed specifically for the shopping (pabili) and food order services.

### Order Management Workflow

On the merchant app, merchants follow a simple order workflow:

1. Receive incoming orders from customers or the admin dashboard
2. Confirm the order after reviewing details
3. Prepare the order for pickup by the assigned rider

### Order Status Categories

The merchant app manages orders through three main status categories:

- **New** - Freshly received orders waiting for merchant review
- **Confirmed** - Orders that have been accepted and are being prepared
- **For Pickup** - Ready orders waiting for rider collection

## Service Types Breakdown

**Food Order Service:** When a customer downloads the app or opens it and places a food order, they see a list of restaurants. When they choose a specific restaurant, they would be able to see the list of items available at that restaurant. When they want to order an item, they just add it to the cart, or before adding it to the cart, they can edit it with configurations like sizes and other related adjustments to the product or item. Once the cart is ready, or once the users or customers decide to proceed with the cart and double-check their order, they will be able to place an order, and it would be reflected on the admin dashboard that there's a new order.

**Transportation Service:** For the transport service, it would be similar to Uber or Grab, where they can request transportation service, or some sort of ride-hailing app where they will be picked up from one point to another. How it works is they usually set a pickup point, which is the location of the customer or person who will be picked up by the driver. Then the user will also set the drop-off point where the driver will drop off the customer.

**Pickup and Delivery Service:** This is the default or basic purpose of the customer app, where they can book pickup and delivery. They will set the pickup details and delivery details, and also the details of the items that they want to send or deliver or request for pickup and delivery.

**Errand Service:** The errand service is a request where the customer requests a specific thing. For example, "buy this in the market" or "pay these bills to this office," or anything that involves a request or an errand.

**Shopping Service:** The shopping service typically involves three categories: pharmacies, groceries, and retail stores. Customers can place an order or request a purchase from those stores. For example, if they want to purchase medicine from a specific pharmacy, they can input the details there.

## Admin Dashboard Details

For the admin dashboard, it's typically a dispatching system where all orders or transactions that were created throughout the system or application will be dispatched to the rider for their respective service type. Initially, I mentioned earlier that this app caters to pickup and delivery, so mostly it's centered on last mile delivery, but with the addition of add-ons, it expands a bit.

For the admin dashboard, we offer this to our clients, our direct clients, which I've mentioned earlier. Its main purpose is to dispatch orders. When dispatching, orders can be dispatched manually or automatically to the riders. For manual dispatching, they just have to select the order and manually assign it to the rider. For automated assignment, the system identifies the best rider for the job or order completion.

## Multi-Task Assignment and Route Optimization

Regarding tasks, tasks and orders can be assigned multiple to a single rider. For example, if there are five requests for pickup and delivery, or let's just say delivery, they can all be assigned to a rider and can be formed into a route. A route typically means a collection or group of stops or points that the rider should be going to. It's from point A to point B to C to D, up to the end of the route.

This also has a route optimization feature where the system identifies the best sequence and best route for the riders to take in order for them to save time, save on gas, and save on effort. It would require minimal effort for the drivers without them thinking about which streets or paths to take, or which deliveries should come first.

## Additional Admin Features

Also on the admin dashboard, they will see analytics of how the business or operations are performing. It involves analytics and also management of riders, where they can add and edit riders, and also customers. If they want to specifically invite customers, they will send invites through email for them to have their own accounts.

For configuration, there will be configuration of available services. The available services will be reflected on the customer app where customers will see the available services depending on what our clients offer. By default, the available service is only pickup and delivery, but our clients or tenants can configure those depending on their business model or operations. They can enable everything from food orders, shopping service, errand service, and transportation.

## Multi-Hub Model

The admin dashboard also includes a feature that lets you have multiple hubs, warehouses, offices, or branches. These can be interconnected or have an overview of those branches. It's a multi-hub model, or some sort of hub and spoke model on some platforms or applications.

The idea is, if our customer is a local delivery service and in their province they cater to different cities—let's say three: City A, City B, and City C—they want to have a single account for all of those and want to have an overview of everything. For City A, City B, and City C, they will be able to see everything at one glance, especially if they're a super admin or have access to all those branches.

There are user groups or user permissions for this. For example, an admin on City A can only see their data, and City B can only view their data, while the super admin, or probably the owners or higher positions in the company, can see all of those.
