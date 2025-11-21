namespace LoansUnderwriting.Domain.Entities
{
    public class LoanApplication
    {
        public Guid Id { get; set; }
        public string ApplicationNumber { get; set; } = string.Empty;
        public Guid MemberId { get; set; }
        public decimal LoanAmount { get; set; }
        public string LoanPurpose { get; set; } = string.Empty;
        public int RequestedTerm { get; set; }
        public LoanApplicationStatus Status { get; set; }
        public string ProgramCode { get; set; } = string.Empty;
        public DateTime SubmissionDate { get; set; }
        public DateTime LastUpdated { get; set; }
        public string? Notes { get; set; }
        public decimal? RequestedInterestRate { get; set; }

        // Navigation properties
        public ICollection<Document> Documents { get; set; } = new List<Document>();
        public ICollection<CreditCheck> CreditChecks { get; set; } = new List<CreditCheck>();
        public ICollection<UnderwritingDecision> UnderwritingDecisions { get; set; } = new List<UnderwritingDecision>();
        public Loan? Loan { get; set; }

        public bool IsEligibleForProgram(string programCode) => ProgramCode == programCode;
        public TimeSpan ProcessingTime => DateTime.UtcNow - SubmissionDate;
    }

    public class Loan
    {
        public Guid Id { get; set; }
        public string LoanNumber { get; set; } = string.Empty;
        public Guid ApplicationId { get; set; }
        public decimal PrincipalAmount { get; set; }
        public decimal InterestRate { get; set; }
        public int TermInMonths { get; set; }
        public decimal MonthlyPayment { get; set; }
        public LoanStatus Status { get; set; }
        public DateTime OriginationDate { get; set; }
        public DateTime MaturityDate { get; set; }
        public decimal CurrentBalance { get; set; }
        public decimal TotalPaid { get; set; }
        public int PaymentsMade { get; set; }
        public DateTime? LastPaymentDate { get; set; }

        // Navigation properties
        public LoanApplication Application { get; set; } = null!;
        public ICollection<Payment> Payments { get; set; } = new List<Payment>();
        public ICollection<LoanDocument> Documents { get; set; } = new List<LoanDocument>();

        public decimal RemainingBalance => PrincipalAmount - TotalPaid;
        public int RemainingPayments => TermInMonths - PaymentsMade;
        public bool IsCurrentOnPayments => Status == LoanStatus.Current;
    }

    public class UnderwritingDecision
    {
        public Guid Id { get; set; }
        public Guid ApplicationId { get; set; }
        public UnderwritingDecisionType Decision { get; set; }
        public string? DecisionReason { get; set; }
        public string UnderwriterId { get; set; } = string.Empty;
        public DateTime DecisionDate { get; set; }
        public decimal? RiskScore { get; set; }
        public decimal? DebtToIncomeRatio { get; set; }
        public decimal? ApprovedAmount { get; set; }
        public decimal? ApprovedRate { get; set; }
        public int? ApprovedTerm { get; set; }
        public string? Conditions { get; set; }

        // Navigation properties
        public LoanApplication LoanApplication { get; set; } = null!;

        public bool IsApproved => Decision == UnderwritingDecisionType.Approved;
        public bool RequiresConditions => !string.IsNullOrEmpty(Conditions);
    }

    public class Document
    {
        public Guid Id { get; set; }
        public Guid LoanApplicationId { get; set; }
        public DocumentType DocumentType { get; set; }
        public string FileName { get; set; } = string.Empty;
        public long FileSize { get; set; }
        public string MimeType { get; set; } = string.Empty;
        public string StoragePath { get; set; } = string.Empty;
        public DateTime UploadedAt { get; set; }
        public string UploadedBy { get; set; } = string.Empty;
        public DocumentStatus Status { get; set; }
        public string? ReviewNotes { get; set; }

        // Navigation properties
        public LoanApplication LoanApplication { get; set; } = null!;

        public bool IsValid => Status == DocumentStatus.Verified;
        public TimeSpan Age => DateTime.UtcNow - UploadedAt;
    }

    public class CreditCheck
    {
        public Guid Id { get; set; }
        public Guid LoanApplicationId { get; set; }
        public string CreditBureau { get; set; } = string.Empty;
        public int CreditScore { get; set; }
        public DateTime CheckDate { get; set; }
        public string? ReportData { get; set; }
        public decimal? TotalDebt { get; set; }
        public int? OpenAccounts { get; set; }
        public decimal? MonthlyDebtPayments { get; set; }
        public string? CreditGrade { get; set; }

        // Navigation properties
        public LoanApplication LoanApplication { get; set; } = null!;

        public bool IsGoodCredit => CreditScore >= 700;
        public TimeSpan ReportAge => DateTime.UtcNow - CheckDate;
    }

    public class Payment
    {
        public Guid Id { get; set; }
        public Guid LoanId { get; set; }
        public decimal Amount { get; set; }
        public decimal PrincipalAmount { get; set; }
        public decimal InterestAmount { get; set; }
        public DateTime PaymentDate { get; set; }
        public DateTime DueDate { get; set; }
        public PaymentStatus Status { get; set; }
        public PaymentMethod PaymentMethod { get; set; }
        public string? TransactionId { get; set; }

        // Navigation properties
        public Loan Loan { get; set; } = null!;

        public bool IsLate => PaymentDate > DueDate;
        public int DaysLate => IsLate ? (PaymentDate - DueDate).Days : 0;
    }

    public class LoanDocument
    {
        public Guid Id { get; set; }
        public Guid LoanId { get; set; }
        public string DocumentType { get; set; } = string.Empty;
        public string FileName { get; set; } = string.Empty;
        public string StoragePath { get; set; } = string.Empty;
        public DateTime CreatedDate { get; set; }

        // Navigation properties
        public Loan Loan { get; set; } = null!;
    }

    public enum LoanApplicationStatus
    {
        Draft,
        Submitted,
        UnderReview,
        PendingDocuments,
        Underwriting,
        Approved,
        Denied,
        Withdrawn,
        Expired
    }

    public enum LoanStatus
    {
        Active,
        Current,
        Delinquent,
        Default,
        PaidOff,
        ChargedOff,
        Refinanced
    }

    public enum UnderwritingDecisionType
    {
        Approved,
        Denied,
        ConditionalApproval,
        PendingInformation
    }

    public enum DocumentType
    {
        IncomeVerification,
        EmploymentVerification,
        BankStatements,
        TaxReturns,
        AssetDocuments,
        IdentityDocuments,
        Other
    }

    public enum DocumentStatus
    {
        Uploaded,
        UnderReview,
        Verified,
        Rejected,
        Expired
    }

    public enum PaymentStatus
    {
        Pending,
        Processed,
        Failed,
        Cancelled,
        Refunded
    }

    public enum PaymentMethod
    {
        ACH,
        Check,
        Wire,
        Online,
        AutoPay
    }
}