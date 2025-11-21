namespace NotificationServices.Domain.Entities;

public class Notification
{
    public int Id { get; set; }
    public string RecipientId { get; set; } = string.Empty;
    public string RecipientEmail { get; set; } = string.Empty;
    public string? RecipientPhone { get; set; }
    public string Channel { get; set; } = string.Empty; // Email, SMS, Push
    public string Type { get; set; } = string.Empty; // LoanStatus, PaymentDue, FraudAlert, AccountActivity
    public string Subject { get; set; } = string.Empty;
    public string Message { get; set; } = string.Empty;
    public string Status { get; set; } = "Pending"; // Pending, Sent, Failed, Delivered
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? SentAt { get; set; }
    public DateTime? DeliveredAt { get; set; }
    public string? ErrorMessage { get; set; }
    public int RetryCount { get; set; } = 0;
    public string? Metadata { get; set; } // JSON for additional data
}
