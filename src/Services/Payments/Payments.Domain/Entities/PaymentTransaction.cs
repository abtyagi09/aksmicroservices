namespace Payments.Domain.Entities
{
    public class PaymentTransaction
    {
        public Guid Id { get; set; }
        public string TransactionNumber { get; set; } = string.Empty;
        public Guid? LoanId { get; set; }
        public Guid PayerId { get; set; }
        public decimal Amount { get; set; }
        public PaymentType PaymentType { get; set; }
        public PaymentMethod PaymentMethod { get; set; }
        public PaymentStatus Status { get; set; }
        public DateTime TransactionDate { get; set; }
        public DateTime? ProcessedDate { get; set; }
        public string? ProcessorTransactionId { get; set; }
        public string? ProcessorName { get; set; }
        public string? FailureReason { get; set; }
        public decimal ProcessingFee { get; set; }

        // Navigation properties
        public PaymentAccount? PaymentAccount { get; set; }
        public ICollection<PaymentAttempt> PaymentAttempts { get; set; } = new List<PaymentAttempt>();
        public ICollection<RefundTransaction> Refunds { get; set; } = new List<RefundTransaction>();

        public bool IsSuccessful => Status == PaymentStatus.Completed;
        public bool CanBeRefunded => IsSuccessful && Refunds.Sum(r => r.Amount) < Amount;
        public decimal NetAmount => Amount - ProcessingFee;
    }

    public class PaymentAccount
    {
        public Guid Id { get; set; }
        public Guid MemberId { get; set; }
        public AccountType AccountType { get; set; }
        public string AccountNumber { get; set; } = string.Empty;
        public string RoutingNumber { get; set; } = string.Empty;
        public string BankName { get; set; } = string.Empty;
        public string AccountHolderName { get; set; } = string.Empty;
        public bool IsActive { get; set; }
        public bool IsVerified { get; set; }
        public DateTime CreatedDate { get; set; }
        public DateTime? VerifiedDate { get; set; }
        public DateTime? LastUsedDate { get; set; }

        // Navigation properties
        public ICollection<PaymentTransaction> Transactions { get; set; } = new List<PaymentTransaction>();
        public ICollection<AccountVerification> Verifications { get; set; } = new List<AccountVerification>();

        public bool CanProcessPayments => IsActive && IsVerified;
        public string MaskedAccountNumber => $"****{AccountNumber.Substring(Math.Max(0, AccountNumber.Length - 4))}";
    }

    public class PaymentAttempt
    {
        public Guid Id { get; set; }
        public Guid TransactionId { get; set; }
        public int AttemptNumber { get; set; }
        public DateTime AttemptDate { get; set; }
        public PaymentAttemptStatus Status { get; set; }
        public string? ResponseCode { get; set; }
        public string? ResponseMessage { get; set; }
        public string? ProcessorResponse { get; set; }

        // Navigation properties
        public PaymentTransaction Transaction { get; set; } = null!;

        public bool WasSuccessful => Status == PaymentAttemptStatus.Success;
    }

    public class RefundTransaction
    {
        public Guid Id { get; set; }
        public Guid OriginalTransactionId { get; set; }
        public string RefundNumber { get; set; } = string.Empty;
        public decimal Amount { get; set; }
        public RefundReason Reason { get; set; }
        public RefundStatus Status { get; set; }
        public DateTime RequestDate { get; set; }
        public DateTime? ProcessedDate { get; set; }
        public string RequestedBy { get; set; } = string.Empty;
        public string? Notes { get; set; }
        public string? ProcessorRefundId { get; set; }

        // Navigation properties
        public PaymentTransaction OriginalTransaction { get; set; } = null!;

        public bool IsCompleted => Status == RefundStatus.Completed;
        public TimeSpan ProcessingTime => (ProcessedDate ?? DateTime.UtcNow) - RequestDate;
    }

    public class AccountVerification
    {
        public Guid Id { get; set; }
        public Guid PaymentAccountId { get; set; }
        public VerificationMethod Method { get; set; }
        public VerificationStatus Status { get; set; }
        public DateTime InitiatedDate { get; set; }
        public DateTime? CompletedDate { get; set; }
        public decimal? VerificationAmount1 { get; set; }
        public decimal? VerificationAmount2 { get; set; }
        public int AttemptCount { get; set; }
        public DateTime? ExpirationDate { get; set; }

        // Navigation properties
        public PaymentAccount PaymentAccount { get; set; } = null!;

        public bool IsVerified => Status == VerificationStatus.Verified;
        public bool IsExpired => ExpirationDate.HasValue && DateTime.UtcNow > ExpirationDate;
    }

    public class PaymentSchedule
    {
        public Guid Id { get; set; }
        public Guid LoanId { get; set; }
        public Guid PaymentAccountId { get; set; }
        public decimal Amount { get; set; }
        public ScheduleFrequency Frequency { get; set; }
        public DateTime StartDate { get; set; }
        public DateTime? EndDate { get; set; }
        public bool IsActive { get; set; }
        public DateTime? NextPaymentDate { get; set; }
        public DateTime CreatedDate { get; set; }

        // Navigation properties
        public PaymentAccount PaymentAccount { get; set; } = null!;
        public ICollection<ScheduledPayment> ScheduledPayments { get; set; } = new List<ScheduledPayment>();

        public bool IsCurrentlyActive => IsActive && (EndDate == null || DateTime.UtcNow <= EndDate);
    }

    public class ScheduledPayment
    {
        public Guid Id { get; set; }
        public Guid PaymentScheduleId { get; set; }
        public DateTime ScheduledDate { get; set; }
        public decimal Amount { get; set; }
        public ScheduledPaymentStatus Status { get; set; }
        public Guid? TransactionId { get; set; }
        public DateTime? ProcessedDate { get; set; }
        public string? FailureReason { get; set; }

        // Navigation properties
        public PaymentSchedule PaymentSchedule { get; set; } = null!;
        public PaymentTransaction? Transaction { get; set; }

        public bool IsOverdue => Status == ScheduledPaymentStatus.Pending && DateTime.UtcNow > ScheduledDate;
    }

    public enum PaymentType
    {
        LoanPayment,
        LatePayment,
        PrincipalPayment,
        InterestPayment,
        Fee,
        Refund
    }

    public enum PaymentMethod
    {
        ACH,
        DebitCard,
        CreditCard,
        Check,
        Wire,
        Cash
    }

    public enum PaymentStatus
    {
        Pending,
        Processing,
        Completed,
        Failed,
        Cancelled,
        Refunded,
        Reversed
    }

    public enum AccountType
    {
        Checking,
        Savings
    }

    public enum PaymentAttemptStatus
    {
        Pending,
        Success,
        Failed,
        Timeout,
        Error
    }

    public enum RefundReason
    {
        CustomerRequest,
        DuplicatePayment,
        ErrorCorrection,
        ChargeDispute,
        SystemError,
        Other
    }

    public enum RefundStatus
    {
        Requested,
        Approved,
        Processing,
        Completed,
        Failed,
        Cancelled
    }

    public enum VerificationMethod
    {
        MicroDeposits,
        InstantVerification,
        PlaidVerification
    }

    public enum VerificationStatus
    {
        Pending,
        InProgress,
        Verified,
        Failed,
        Expired
    }

    public enum ScheduleFrequency
    {
        Weekly,
        BiWeekly,
        Monthly,
        Quarterly
    }

    public enum ScheduledPaymentStatus
    {
        Pending,
        Processed,
        Failed,
        Cancelled,
        Skipped
    }
}