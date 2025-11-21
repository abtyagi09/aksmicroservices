using Microsoft.AspNetCore.DataProtection;
using System.Security.Cryptography;
using System.Text;

namespace Shared.Common.Security
{
    public interface IEncryptionService
    {
        string EncryptPII(string plainText);
        string DecryptPII(string encryptedText);
        string HashSSN(string ssn);
        bool VerifySSN(string ssn, string hash);
        string MaskPII(string data, PIIType type);
    }

    public class EncryptionService : IEncryptionService
    {
        private readonly IDataProtectionProvider _dataProtectionProvider;
        private readonly IDataProtector _piiProtector;
        private readonly ILogger<EncryptionService> _logger;

        public EncryptionService(IDataProtectionProvider dataProtectionProvider, ILogger<EncryptionService> logger)
        {
            _dataProtectionProvider = dataProtectionProvider;
            _piiProtector = _dataProtectionProvider.CreateProtector("PII.Protection.v1");
            _logger = logger;
        }

        public string EncryptPII(string plainText)
        {
            if (string.IsNullOrEmpty(plainText))
                return string.Empty;

            try
            {
                return _piiProtector.Protect(plainText);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to encrypt PII data");
                throw new SecurityException("Encryption operation failed", ex);
            }
        }

        public string DecryptPII(string encryptedText)
        {
            if (string.IsNullOrEmpty(encryptedText))
                return string.Empty;

            try
            {
                return _piiProtector.Unprotect(encryptedText);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to decrypt PII data");
                throw new SecurityException("Decryption operation failed", ex);
            }
        }

        public string HashSSN(string ssn)
        {
            if (string.IsNullOrEmpty(ssn))
                return string.Empty;

            // Remove any formatting from SSN
            string cleanSSN = ssn.Replace("-", "").Replace(" ", "");
            
            // Add salt for additional security
            string saltedSSN = $"{cleanSSN}_{Environment.GetEnvironmentVariable("SSN_SALT") ?? "DEFAULT_SALT"}";
            
            using var sha256 = SHA256.Create();
            byte[] hashedBytes = sha256.ComputeHash(Encoding.UTF8.GetBytes(saltedSSN));
            return Convert.ToBase64String(hashedBytes);
        }

        public bool VerifySSN(string ssn, string hash)
        {
            return HashSSN(ssn) == hash;
        }

        public string MaskPII(string data, PIIType type)
        {
            if (string.IsNullOrEmpty(data))
                return string.Empty;

            return type switch
            {
                PIIType.SSN => MaskSSN(data),
                PIIType.Email => MaskEmail(data),
                PIIType.Phone => MaskPhone(data),
                PIIType.BankAccount => MaskBankAccount(data),
                PIIType.CreditCard => MaskCreditCard(data),
                _ => data
            };
        }

        private string MaskSSN(string ssn)
        {
            if (ssn.Length >= 4)
                return $"XXX-XX-{ssn.Substring(ssn.Length - 4)}";
            return "XXX-XX-XXXX";
        }

        private string MaskEmail(string email)
        {
            if (email.Contains('@'))
            {
                var parts = email.Split('@');
                if (parts[0].Length > 2)
                    return $"{parts[0].Substring(0, 2)}***@{parts[1]}";
                return $"***@{parts[1]}";
            }
            return email;
        }

        private string MaskPhone(string phone)
        {
            var digits = new string(phone.Where(char.IsDigit).ToArray());
            if (digits.Length >= 4)
                return $"***-***-{digits.Substring(digits.Length - 4)}";
            return "***-***-****";
        }

        private string MaskBankAccount(string account)
        {
            if (account.Length >= 4)
                return $"****{account.Substring(account.Length - 4)}";
            return "****";
        }

        private string MaskCreditCard(string card)
        {
            var digits = new string(card.Where(char.IsDigit).ToArray());
            if (digits.Length >= 4)
                return $"****-****-****-{digits.Substring(digits.Length - 4)}";
            return "****-****-****-****";
        }
    }

    public enum PIIType
    {
        SSN,
        Email,
        Phone,
        BankAccount,
        CreditCard
    }

    public class SecurityException : Exception
    {
        public SecurityException(string message) : base(message) { }
        public SecurityException(string message, Exception innerException) : base(message, innerException) { }
    }
}

namespace Shared.Common.Compliance
{
    public interface IAuditService
    {
        Task LogUserActionAsync(string userId, string action, string entityType, string entityId, object? oldValue = null, object? newValue = null);
        Task LogSecurityEventAsync(SecurityEventType eventType, string userId, string details, string ipAddress);
        Task LogDataAccessAsync(string userId, string dataType, string purpose, string ipAddress);
        Task<IEnumerable<AuditRecord>> GetAuditTrailAsync(string entityId, DateTime? fromDate = null, DateTime? toDate = null);
    }

    public class AuditService : IAuditService
    {
        private readonly ILogger<AuditService> _logger;
        private readonly IAuditRepository _auditRepository;

        public AuditService(ILogger<AuditService> logger, IAuditRepository auditRepository)
        {
            _logger = logger;
            _auditRepository = auditRepository;
        }

        public async Task LogUserActionAsync(string userId, string action, string entityType, string entityId, object? oldValue = null, object? newValue = null)
        {
            var auditRecord = new AuditRecord
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                Action = action,
                EntityType = entityType,
                EntityId = entityId,
                OldValue = oldValue != null ? JsonSerializer.Serialize(oldValue) : null,
                NewValue = newValue != null ? JsonSerializer.Serialize(newValue) : null,
                Timestamp = DateTime.UtcNow,
                IPAddress = GetCurrentIPAddress(),
                UserAgent = GetCurrentUserAgent()
            };

            await _auditRepository.CreateAsync(auditRecord);
            
            _logger.LogInformation("User action logged: {UserId} performed {Action} on {EntityType} {EntityId}",
                userId, action, entityType, entityId);
        }

        public async Task LogSecurityEventAsync(SecurityEventType eventType, string userId, string details, string ipAddress)
        {
            var auditRecord = new AuditRecord
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                Action = $"SECURITY_EVENT_{eventType}",
                EntityType = "SECURITY",
                EntityId = Guid.NewGuid().ToString(),
                NewValue = details,
                Timestamp = DateTime.UtcNow,
                IPAddress = ipAddress,
                Severity = GetSecurityEventSeverity(eventType)
            };

            await _auditRepository.CreateAsync(auditRecord);

            _logger.LogWarning("Security event logged: {EventType} for user {UserId} from IP {IPAddress}",
                eventType, userId, ipAddress);
        }

        public async Task LogDataAccessAsync(string userId, string dataType, string purpose, string ipAddress)
        {
            var auditRecord = new AuditRecord
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                Action = "DATA_ACCESS",
                EntityType = dataType,
                EntityId = Guid.NewGuid().ToString(),
                NewValue = $"Purpose: {purpose}",
                Timestamp = DateTime.UtcNow,
                IPAddress = ipAddress
            };

            await _auditRepository.CreateAsync(auditRecord);

            _logger.LogInformation("Data access logged: {UserId} accessed {DataType} for {Purpose}",
                userId, dataType, purpose);
        }

        public async Task<IEnumerable<AuditRecord>> GetAuditTrailAsync(string entityId, DateTime? fromDate = null, DateTime? toDate = null)
        {
            return await _auditRepository.GetAuditTrailAsync(entityId, fromDate, toDate);
        }

        private string GetCurrentIPAddress()
        {
            // Implementation to get current HTTP context IP address
            return "0.0.0.0"; // Placeholder
        }

        private string GetCurrentUserAgent()
        {
            // Implementation to get current HTTP context user agent
            return "Unknown"; // Placeholder
        }

        private AuditSeverity GetSecurityEventSeverity(SecurityEventType eventType)
        {
            return eventType switch
            {
                SecurityEventType.LoginFailure => AuditSeverity.Medium,
                SecurityEventType.UnauthorizedAccess => AuditSeverity.High,
                SecurityEventType.DataBreach => AuditSeverity.Critical,
                SecurityEventType.PasswordChange => AuditSeverity.Low,
                SecurityEventType.AccountLockout => AuditSeverity.Medium,
                _ => AuditSeverity.Low
            };
        }
    }

    public class AuditRecord
    {
        public Guid Id { get; set; }
        public string UserId { get; set; } = string.Empty;
        public string Action { get; set; } = string.Empty;
        public string EntityType { get; set; } = string.Empty;
        public string EntityId { get; set; } = string.Empty;
        public string? OldValue { get; set; }
        public string? NewValue { get; set; }
        public DateTime Timestamp { get; set; }
        public string IPAddress { get; set; } = string.Empty;
        public string? UserAgent { get; set; }
        public AuditSeverity Severity { get; set; }
    }

    public interface IAuditRepository
    {
        Task CreateAsync(AuditRecord auditRecord);
        Task<IEnumerable<AuditRecord>> GetAuditTrailAsync(string entityId, DateTime? fromDate = null, DateTime? toDate = null);
    }

    public enum SecurityEventType
    {
        LoginFailure,
        UnauthorizedAccess,
        DataBreach,
        PasswordChange,
        AccountLockout,
        SuspiciousActivity
    }

    public enum AuditSeverity
    {
        Low,
        Medium,
        High,
        Critical
    }
}

namespace Shared.Common.Validation
{
    public static class PCICompliance
    {
        public static bool ValidateCardNumber(string cardNumber)
        {
            // Luhn algorithm implementation
            if (string.IsNullOrWhiteSpace(cardNumber))
                return false;

            cardNumber = cardNumber.Replace(" ", "").Replace("-", "");
            
            if (!cardNumber.All(char.IsDigit) || cardNumber.Length < 13 || cardNumber.Length > 19)
                return false;

            int sum = 0;
            bool alternate = false;

            for (int i = cardNumber.Length - 1; i >= 0; i--)
            {
                int digit = int.Parse(cardNumber[i].ToString());
                
                if (alternate)
                {
                    digit *= 2;
                    if (digit > 9)
                        digit = digit / 10 + digit % 10;
                }
                
                sum += digit;
                alternate = !alternate;
            }

            return sum % 10 == 0;
        }

        public static bool ValidateExpiryDate(string expiryDate)
        {
            if (string.IsNullOrWhiteSpace(expiryDate))
                return false;

            var parts = expiryDate.Split('/');
            if (parts.Length != 2)
                return false;

            if (!int.TryParse(parts[0], out int month) || !int.TryParse(parts[1], out int year))
                return false;

            if (month < 1 || month > 12)
                return false;

            // Assume 2-digit year
            if (year < 100)
                year += 2000;

            var expiry = new DateTime(year, month, DateTime.DaysInMonth(year, month));
            return expiry >= DateTime.Now.Date;
        }

        public static bool ValidateCVV(string cvv, string cardType)
        {
            if (string.IsNullOrWhiteSpace(cvv) || !cvv.All(char.IsDigit))
                return false;

            return cardType?.ToUpper() switch
            {
                "AMEX" => cvv.Length == 4,
                _ => cvv.Length == 3
            };
        }
    }

    public static class SOXCompliance
    {
        public static bool ValidateChangeApproval(string changeRequest, string approver, string requester)
        {
            // Segregation of duties - approver cannot be the same as requester
            return !string.Equals(approver, requester, StringComparison.OrdinalIgnoreCase);
        }

        public static bool RequiresSOXApproval(decimal amount, string transactionType)
        {
            // Define SOX approval thresholds
            return transactionType.ToUpper() switch
            {
                "LOAN_APPROVAL" => amount >= 100000,
                "PAYMENT_REVERSAL" => amount >= 10000,
                "ACCOUNT_CLOSURE" => true,
                "RATE_CHANGE" => amount >= 50000,
                _ => amount >= 25000
            };
        }

        public static TimeSpan GetRetentionPeriod(string documentType)
        {
            return documentType.ToUpper() switch
            {
                "FINANCIAL_STATEMENT" => TimeSpan.FromDays(7 * 365), // 7 years
                "LOAN_DOCUMENT" => TimeSpan.FromDays(7 * 365),
                "AUDIT_LOG" => TimeSpan.FromDays(7 * 365),
                "TRANSACTION_RECORD" => TimeSpan.FromDays(5 * 365), // 5 years
                "CUSTOMER_COMMUNICATION" => TimeSpan.FromDays(3 * 365), // 3 years
                _ => TimeSpan.FromDays(7 * 365) // Default to 7 years
            };
        }
    }
}