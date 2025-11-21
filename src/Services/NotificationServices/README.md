# Notification Services API

## Overview
The Notification Services microservice is responsible for managing and delivering notifications to customers across multiple channels (Email, SMS, Push notifications). This service integrates with other microservices to deliver timely updates about loans, payments, fraud alerts, and account activities.

## Architecture
- **Domain Layer**: Contains entity models and business logic
- **Infrastructure Layer**: Data access and external service integrations
- **API Layer**: REST API endpoints for notification management

## Key Features
- Multi-channel notification delivery (Email, SMS, Push)
- Support for multiple notification types:
  - Loan status updates
  - Payment due reminders
  - Fraud detection alerts
  - Account activity notifications
- Notification tracking and status management
- Retry mechanism for failed deliveries
- Health check endpoints for monitoring

## API Endpoints

### Base URL
`/api/notifications`

### Endpoints

#### Get All Notifications
```
GET /api/notifications
```
Returns a list of recent notifications with their status.

#### Get Notification by ID
```
GET /api/notifications/{id}
```
Returns details of a specific notification.

#### Create Notification
```
POST /api/notifications
```
Creates a new notification.

**Request Body:**
```json
{
  "recipientEmail": "customer@example.com",
  "recipientPhone": "+1234567890",
  "channel": "Email",
  "type": "LoanStatus",
  "subject": "Loan Application Update",
  "message": "Your loan application has been approved."
}
```

#### Send Notification
```
POST /api/notifications/{id}/send
```
Triggers sending of a pending notification.

#### Get Notification Types
```
GET /api/notifications/types
```
Returns all supported notification types.

#### Get Notification Channels
```
GET /api/notifications/channels
```
Returns all available notification channels.

#### Health Check
```
GET /api/notifications/health
```
Returns service health status.

## Domain Model

### Notification Entity
- **Id**: Unique identifier
- **RecipientId**: Customer identifier
- **RecipientEmail**: Customer email address
- **RecipientPhone**: Customer phone number (optional)
- **Channel**: Delivery channel (Email, SMS, Push)
- **Type**: Notification type (LoanStatus, PaymentDue, FraudAlert, AccountActivity)
- **Subject**: Notification subject/title
- **Message**: Notification content
- **Status**: Current status (Pending, Sent, Failed, Delivered)
- **CreatedAt**: Creation timestamp
- **SentAt**: Sending timestamp
- **DeliveredAt**: Delivery timestamp
- **ErrorMessage**: Error details if failed
- **RetryCount**: Number of retry attempts
- **Metadata**: Additional JSON metadata

## Configuration

### Environment Variables
- `ASPNETCORE_ENVIRONMENT`: Application environment (Development/Production)
- `ASPNETCORE_URLS`: HTTP binding URLs
- `ConnectionStrings__DefaultConnection`: Database connection string (future)
- `NotificationServices__EmailProvider`: Email service provider configuration
- `NotificationServices__SmsProvider`: SMS service provider configuration

## Deployment

### Docker
Build and run the service using Docker:
```bash
docker build -f src/Services/NotificationServices/Dockerfile -t notificationservices:latest .
docker run -p 8080:80 notificationservices:latest
```

### Kubernetes
Deploy to Kubernetes cluster:
```bash
kubectl apply -f k8s/notificationservices/deployment.yaml
```

## Integration with Other Services

### Member Services
- Notifications for account updates and eligibility changes

### Loans & Underwriting
- Loan application status notifications
- Approval/rejection notifications
- Document request notifications

### Payments
- Payment due reminders
- Payment confirmation notifications
- Failed payment alerts

### Fraud/Risk
- Suspicious activity alerts
- Account security notifications
- Risk assessment updates

## Development

### Build
```bash
dotnet build src/Services/NotificationServices/NotificationServices.API/NotificationServices.API.csproj
```

### Run
```bash
dotnet run --project src/Services/NotificationServices/NotificationServices.API/NotificationServices.API.csproj
```

### Test
```bash
# Access Swagger UI in development
http://localhost:5000/swagger

# Health check
curl http://localhost:5000/api/notifications/health
```

## Future Enhancements
- Database persistence with Entity Framework
- Azure Service Bus integration for async processing
- Template management for notification content
- Delivery status webhooks
- User preference management
- Rate limiting per channel
- Analytics and reporting
- Multi-language support

## Version
1.0.0

## License
© 2025 Farmers Bank. All rights reserved. Proprietary and confidential.
