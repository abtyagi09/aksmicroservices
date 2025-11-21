using Microsoft.AspNetCore.Mvc;

namespace NotificationServices.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class NotificationsController : ControllerBase
{
    private readonly ILogger<NotificationsController> _logger;

    public NotificationsController(ILogger<NotificationsController> logger)
    {
        _logger = logger;
    }

    [HttpGet]
    public IActionResult Get()
    {
        var notifications = new[]
        {
            new { Id = 1, RecipientEmail = "john.farmer@example.com", Channel = "Email", Type = "LoanStatus", Subject = "Loan Application Approved", Status = "Sent", CreatedAt = DateTime.UtcNow.AddHours(-2) },
            new { Id = 2, RecipientEmail = "jane.agriculture@example.com", Channel = "SMS", Type = "PaymentDue", Subject = "Payment Due Reminder", Status = "Delivered", CreatedAt = DateTime.UtcNow.AddHours(-5) },
            new { Id = 3, RecipientEmail = "bob.rancher@example.com", Channel = "Push", Type = "FraudAlert", Subject = "Suspicious Activity Detected", Status = "Sent", CreatedAt = DateTime.UtcNow.AddMinutes(-30) }
        };

        return Ok(new
        {
            Message = "Farmers Bank Notification Services API",
            Notifications = notifications,
            Service = "Notification Services",
            Version = "1.0",
            Timestamp = DateTime.UtcNow
        });
    }

    [HttpGet("health")]
    public IActionResult Health()
    {
        return Ok(new
        {
            Status = "Healthy",
            Service = "Notification Services",
            Timestamp = DateTime.UtcNow,
            Version = "1.0.0"
        });
    }

    [HttpGet("{id}")]
    public IActionResult GetNotification(int id)
    {
        var notification = new
        {
            Id = id,
            RecipientEmail = $"customer{id}@example.com",
            RecipientPhone = "+1234567890",
            Channel = "Email",
            Type = "LoanStatus",
            Subject = "Your Loan Application Update",
            Message = "Your loan application has been received and is under review.",
            Status = "Sent",
            CreatedAt = DateTime.UtcNow.AddHours(-1),
            SentAt = DateTime.UtcNow.AddMinutes(-30)
        };

        return Ok(notification);
    }

    [HttpPost]
    public IActionResult CreateNotification([FromBody] NotificationRequest request)
    {
        _logger.LogInformation("Creating notification for {RecipientEmail}", request.RecipientEmail);

        var notification = new
        {
            Id = new Random().Next(1000, 9999),
            RecipientEmail = request.RecipientEmail,
            RecipientPhone = request.RecipientPhone,
            Channel = request.Channel,
            Type = request.Type,
            Subject = request.Subject,
            Message = request.Message,
            Status = "Pending",
            CreatedAt = DateTime.UtcNow
        };

        return CreatedAtAction(nameof(GetNotification), new { id = notification.Id }, notification);
    }

    [HttpPost("{id}/send")]
    public IActionResult SendNotification(int id)
    {
        _logger.LogInformation("Sending notification {NotificationId}", id);

        return Ok(new
        {
            Id = id,
            Status = "Sent",
            SentAt = DateTime.UtcNow,
            Message = "Notification sent successfully"
        });
    }

    [HttpGet("types")]
    public IActionResult GetNotificationTypes()
    {
        var types = new[]
        {
            new { Type = "LoanStatus", Description = "Loan application status updates" },
            new { Type = "PaymentDue", Description = "Payment due date reminders" },
            new { Type = "FraudAlert", Description = "Fraud detection alerts" },
            new { Type = "AccountActivity", Description = "Account activity notifications" }
        };

        return Ok(types);
    }

    [HttpGet("channels")]
    public IActionResult GetNotificationChannels()
    {
        var channels = new[]
        {
            new { Channel = "Email", Enabled = true, Description = "Email notifications" },
            new { Channel = "SMS", Enabled = true, Description = "SMS text messages" },
            new { Channel = "Push", Enabled = true, Description = "Push notifications" }
        };

        return Ok(channels);
    }
}

public record NotificationRequest(
    string RecipientEmail,
    string? RecipientPhone,
    string Channel,
    string Type,
    string Subject,
    string Message
);
