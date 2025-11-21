# Notification Services Integration Guide

## Overview
This document describes how the Notification Services microservice integrates with other services in the Farmers Bank microservices architecture.

## Service Dependencies

### Notification Services (New)
**Purpose**: Centralized notification delivery across multiple channels

**Provides:**
- Email notifications
- SMS notifications
- Push notifications
- Notification status tracking
- Delivery confirmation

**Consumes:**
- No direct dependencies (can be integrated via API calls or message bus)

## Integration Patterns

### 1. Member Services → Notification Services
When member account events occur:

```csharp
// Example: Member registration confirmation
POST /api/notifications
{
  "recipientEmail": "john.farmer@example.com",
  "channel": "Email",
  "type": "AccountActivity",
  "subject": "Welcome to Farmers Bank",
  "message": "Your account has been successfully created."
}
```

**Use Cases:**
- Welcome emails for new members
- Account status change notifications
- Eligibility status updates

### 2. Loans & Underwriting → Notification Services
When loan application status changes:

```csharp
// Example: Loan approval notification
POST /api/notifications
{
  "recipientEmail": "jane.agriculture@example.com",
  "recipientPhone": "+1234567890",
  "channel": "Email",
  "type": "LoanStatus",
  "subject": "Loan Application Approved",
  "message": "Congratulations! Your loan application #12345 has been approved."
}
```

**Use Cases:**
- Loan application received confirmation
- Underwriting status updates
- Approval/rejection notifications
- Document request notifications

### 3. Payments → Notification Services
When payment events occur:

```csharp
// Example: Payment due reminder
POST /api/notifications
{
  "recipientEmail": "bob.rancher@example.com",
  "recipientPhone": "+1234567890",
  "channel": "SMS",
  "type": "PaymentDue",
  "subject": "Payment Due Reminder",
  "message": "Your payment of $500 is due on 2025-12-01. Please ensure sufficient funds."
}
```

**Use Cases:**
- Payment due reminders
- Payment confirmation
- Failed payment alerts
- Recurring payment notifications

### 4. Fraud/Risk → Notification Services
When fraud is detected:

```csharp
// Example: Fraud alert
POST /api/notifications
{
  "recipientEmail": "customer@example.com",
  "recipientPhone": "+1234567890",
  "channel": "Push",
  "type": "FraudAlert",
  "subject": "Suspicious Activity Detected",
  "message": "We detected unusual activity on your account. Please verify immediately."
}
```

**Use Cases:**
- Real-time fraud alerts
- Suspicious transaction notifications
- Account security warnings
- Risk assessment updates

## Message Bus Integration (Future)

### Azure Service Bus Topics
For asynchronous notification delivery:

```yaml
Topics:
  - loan-events
  - payment-events
  - fraud-events
  - member-events

Subscriptions:
  notification-service:
    - loan-events
    - payment-events
    - fraud-events
    - member-events
```

### Event-Driven Flow
1. Service publishes event to topic (e.g., `loan-approved`)
2. Notification Service subscribes to events
3. Notification Service automatically creates and sends notification
4. Status updates published back to status topic

## API Integration Example

### Direct API Call (Synchronous)

```csharp
public class NotificationClient
{
    private readonly HttpClient _httpClient;
    
    public async Task SendLoanApprovalNotification(string email, string loanId)
    {
        var notification = new
        {
            RecipientEmail = email,
            Channel = "Email",
            Type = "LoanStatus",
            Subject = "Loan Approved",
            Message = $"Your loan application {loanId} has been approved!"
        };
        
        var response = await _httpClient.PostAsJsonAsync(
            "http://notificationservices-api-service/api/notifications", 
            notification
        );
        
        response.EnsureSuccessStatusCode();
    }
}
```

### Health Check Integration

```csharp
// Add to other services' health checks
services.AddHealthChecks()
    .AddUrlGroup(
        new Uri("http://notificationservices-api-service/api/notifications/health"),
        name: "notification-service",
        tags: new[] { "external", "notifications" }
    );
```

## Notification Templates (Future Enhancement)

Templates will be stored in Notification Service:

```json
{
  "templateId": "loan-approval",
  "type": "LoanStatus",
  "subject": "Loan Application Approved",
  "bodyTemplate": "Dear {customerName}, your loan application {loanId} for {amount} has been approved. Funds will be disbursed within {disbursementDays} business days.",
  "channels": ["Email", "SMS"]
}
```

## Monitoring Integration

### Application Insights
All services should log notification events:

```csharp
_logger.LogInformation(
    "Notification sent to {Email} for {Type}",
    email, notificationType
);
```

### Metrics to Track
- Notification creation rate
- Delivery success rate
- Channel-specific delivery rates
- Average delivery time
- Failed notification count

## Security Considerations

### Authentication
All API calls should include:
- Bearer token authentication
- Service-to-service authentication
- Rate limiting enforcement

### Data Protection
- PII (email, phone) should be encrypted in transit (TLS)
- Notification content should be sanitized
- Sensitive data should not be logged

## Deployment Considerations

### Namespace
```yaml
namespace: notificationservices-cicd
```

### Service Discovery
Internal services access via:
```
http://notificationservices-api-service.notificationservices-cicd.svc.cluster.local/api/notifications
```

### Resource Requirements
- CPU: 10m-100m (request-limit)
- Memory: 128Mi-256Mi (request-limit)
- Replicas: 1-3 (HPA based on CPU/Memory)

## Testing Integration

### Integration Test Example

```csharp
[Fact]
public async Task LoanApproval_ShouldTriggerNotification()
{
    // Arrange
    var loanId = "TEST-123";
    var email = "test@example.com";
    
    // Act
    await _loanService.ApproveLoan(loanId);
    
    // Assert - Check notification was created
    var notifications = await _notificationClient.GetNotifications();
    var notification = notifications.First(n => 
        n.RecipientEmail == email && 
        n.Type == "LoanStatus"
    );
    
    Assert.Equal("Loan Approved", notification.Subject);
    Assert.Contains(loanId, notification.Message);
}
```

## Rollout Plan

### Phase 1: Basic Integration (Current)
- ✅ Notification Service API deployed
- ✅ REST endpoints available
- ✅ Health checks configured

### Phase 2: Service Integration (Next)
- [ ] Update Loans Service to call Notification API
- [ ] Update Payments Service to call Notification API
- [ ] Update Fraud Service to call Notification API
- [ ] Integration testing

### Phase 3: Async Processing (Future)
- [ ] Implement Azure Service Bus integration
- [ ] Event-driven notification triggers
- [ ] Retry and dead-letter queue handling

### Phase 4: Advanced Features (Future)
- [ ] Template management
- [ ] User preference management
- [ ] Multi-language support
- [ ] Delivery analytics dashboard

## Support

For integration questions or issues:
- **Development Team**: dev-team@farmersbank.com
- **Documentation**: See `/src/Services/NotificationServices/README.md`
- **API Reference**: Swagger UI at `/swagger` endpoint
