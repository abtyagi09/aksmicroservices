namespace FraudRisk.Domain.Entities
{
    public class FraudAlert
    {
        public Guid Id { get; set; }
        public string AlertNumber { get; set; } = string.Empty;
        public FraudAlertType AlertType { get; set; }
        public Severity Severity { get; set; }
        public FraudAlertStatus Status { get; set; }
        public Guid? TransactionId { get; set; }
        public Guid? MemberId { get; set; }
        public Guid? LoanApplicationId { get; set; }
        public decimal? RiskScore { get; set; }
        public string Description { get; set; } = string.Empty;
        public DateTime DetectedAt { get; set; }
        public DateTime? ResolvedAt { get; set; }
        public string? ResolvedBy { get; set; }
        public string? Resolution { get; set; }
        public string? Notes { get; set; }

        // Navigation properties
        public ICollection<FraudRule> TriggeredRules { get; set; } = new List<FraudRule>();
        public ICollection<FraudInvestigation> Investigations { get; set; } = new List<FraudInvestigation>();

        public bool IsResolved => Status == FraudAlertStatus.Resolved;
        public bool IsHighRisk => Severity == Severity.High || Severity == Severity.Critical;
        public TimeSpan ResolutionTime => (ResolvedAt ?? DateTime.UtcNow) - DetectedAt;
    }

    public class RiskAssessment
    {
        public Guid Id { get; set; }
        public Guid EntityId { get; set; }
        public EntityType EntityType { get; set; }
        public decimal OverallRiskScore { get; set; }
        public RiskLevel RiskLevel { get; set; }
        public DateTime AssessmentDate { get; set; }
        public string AssessedBy { get; set; } = string.Empty;
        public DateTime? ExpirationDate { get; set; }
        public string? Notes { get; set; }

        // Navigation properties
        public ICollection<RiskFactor> RiskFactors { get; set; } = new List<RiskFactor>();
        public ICollection<RiskMitigant> Mitigants { get; set; } = new List<RiskMitigant>();

        public bool IsExpired => ExpirationDate.HasValue && DateTime.UtcNow > ExpirationDate;
        public bool RequiresReview => IsExpired || RiskLevel == RiskLevel.High;
    }

    public class FraudRule
    {
        public Guid Id { get; set; }
        public string RuleCode { get; set; } = string.Empty;
        public string RuleName { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;
        public RuleType RuleType { get; set; }
        public string Condition { get; set; } = string.Empty;
        public int Priority { get; set; }
        public bool IsActive { get; set; }
        public DateTime CreatedDate { get; set; }
        public DateTime? LastModified { get; set; }
        public string CreatedBy { get; set; } = string.Empty;

        // Navigation properties
        public ICollection<FraudAlert> TriggeredAlerts { get; set; } = new List<FraudAlert>();
        public ICollection<RuleExecution> Executions { get; set; } = new List<RuleExecution>();

        public bool CanExecute => IsActive;
    }

    public class RuleExecution
    {
        public Guid Id { get; set; }
        public Guid RuleId { get; set; }
        public Guid EntityId { get; set; }
        public EntityType EntityType { get; set; }
        public DateTime ExecutedAt { get; set; }
        public bool WasTriggered { get; set; }
        public string? ExecutionResult { get; set; }
        public TimeSpan ExecutionTime { get; set; }

        // Navigation properties
        public FraudRule Rule { get; set; } = null!;
    }

    public class FraudInvestigation
    {
        public Guid Id { get; set; }
        public Guid AlertId { get; set; }
        public string InvestigationNumber { get; set; } = string.Empty;
        public InvestigationStatus Status { get; set; }
        public Priority Priority { get; set; }
        public string AssignedTo { get; set; } = string.Empty;
        public DateTime StartDate { get; set; }
        public DateTime? CompletionDate { get; set; }
        public string? Findings { get; set; }
        public InvestigationOutcome? Outcome { get; set; }
        public string? ActionsTaken { get; set; }

        // Navigation properties
        public FraudAlert Alert { get; set; } = null!;
        public ICollection<InvestigationNote> Notes { get; set; } = new List<InvestigationNote>();

        public bool IsCompleted => Status == InvestigationStatus.Completed;
        public bool IsOverdue => Status != InvestigationStatus.Completed && DateTime.UtcNow > StartDate.AddDays(GetSLADays());
        
        private int GetSLADays() => Priority switch
        {
            Priority.Low => 30,
            Priority.Medium => 14,
            Priority.High => 7,
            Priority.Critical => 1,
            _ => 14
        };
    }

    public class InvestigationNote
    {
        public Guid Id { get; set; }
        public Guid InvestigationId { get; set; }
        public string Note { get; set; } = string.Empty;
        public string CreatedBy { get; set; } = string.Empty;
        public DateTime CreatedDate { get; set; }
        public bool IsInternal { get; set; }

        // Navigation properties
        public FraudInvestigation Investigation { get; set; } = null!;
    }

    public class RiskFactor
    {
        public Guid Id { get; set; }
        public Guid RiskAssessmentId { get; set; }
        public string FactorName { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;
        public decimal Weight { get; set; }
        public decimal Score { get; set; }
        public string? Details { get; set; }

        // Navigation properties
        public RiskAssessment RiskAssessment { get; set; } = null!;

        public decimal WeightedScore => Score * Weight;
    }

    public class RiskMitigant
    {
        public Guid Id { get; set; }
        public Guid RiskAssessmentId { get; set; }
        public string MitigantType { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;
        public decimal RiskReduction { get; set; }
        public MitigantStatus Status { get; set; }
        public DateTime ImplementedDate { get; set; }
        public DateTime? ExpirationDate { get; set; }

        // Navigation properties
        public RiskAssessment RiskAssessment { get; set; } = null!;

        public bool IsActive => Status == MitigantStatus.Active && 
                              (ExpirationDate == null || DateTime.UtcNow <= ExpirationDate);
    }

    public class BlacklistEntry
    {
        public Guid Id { get; set; }
        public BlacklistType Type { get; set; }
        public string Value { get; set; } = string.Empty;
        public string Reason { get; set; } = string.Empty;
        public DateTime AddedDate { get; set; }
        public string AddedBy { get; set; } = string.Empty;
        public bool IsActive { get; set; }
        public DateTime? ExpirationDate { get; set; }

        public bool IsExpired => ExpirationDate.HasValue && DateTime.UtcNow > ExpirationDate;
        public bool IsCurrentlyBlacklisted => IsActive && !IsExpired;
    }

    public class SuspiciousActivity
    {
        public Guid Id { get; set; }
        public string ActivityType { get; set; } = string.Empty;
        public Guid EntityId { get; set; }
        public EntityType EntityType { get; set; }
        public decimal? Amount { get; set; }
        public DateTime DetectedAt { get; set; }
        public string Description { get; set; } = string.Empty;
        public decimal SuspicionScore { get; set; }
        public ActivityStatus Status { get; set; }
        public string? ReviewedBy { get; set; }
        public DateTime? ReviewedDate { get; set; }

        public bool RequiresReview => Status == ActivityStatus.Detected;
        public bool IsHighSuspicion => SuspicionScore >= 80;
    }

    public enum FraudAlertType
    {
        IdentityTheft,
        DocumentFraud,
        PaymentFraud,
        AccountTakeover,
        SyntheticIdentity,
        ApplicationFraud,
        TransactionAnomaly,
        Other
    }

    public enum Severity
    {
        Low,
        Medium,
        High,
        Critical
    }

    public enum FraudAlertStatus
    {
        Open,
        InProgress,
        Resolved,
        FalsePositive,
        Escalated
    }

    public enum EntityType
    {
        Member,
        Transaction,
        LoanApplication,
        Payment,
        Account
    }

    public enum RiskLevel
    {
        VeryLow,
        Low,
        Medium,
        High,
        VeryHigh
    }

    public enum RuleType
    {
        Threshold,
        Pattern,
        Velocity,
        Anomaly,
        Blacklist,
        Whitelist
    }

    public enum InvestigationStatus
    {
        Open,
        InProgress,
        PendingInfo,
        Completed,
        Cancelled
    }

    public enum Priority
    {
        Low,
        Medium,
        High,
        Critical
    }

    public enum InvestigationOutcome
    {
        Confirmed,
        FalsePositive,
        Inconclusive,
        RequiresEscalation
    }

    public enum MitigantStatus
    {
        Planned,
        Active,
        Expired,
        Ineffective
    }

    public enum BlacklistType
    {
        Email,
        Phone,
        IPAddress,
        DeviceFingerprint,
        BankAccount,
        SSN,
        Address
    }

    public enum ActivityStatus
    {
        Detected,
        Reviewed,
        Confirmed,
        FalsePositive
    }
}