using System.ComponentModel.DataAnnotations;

namespace MemberServices.Domain.Entities
{
    public class Member
    {
        public Guid Id { get; set; }
        public string MemberNumber { get; set; } = string.Empty;
        public string FirstName { get; set; } = string.Empty;
        public string LastName { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public DateTime DateOfBirth { get; set; }
        public string SSN { get; set; } = string.Empty;
        public MemberStatus Status { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime? UpdatedAt { get; set; }

        // Navigation properties
        public MemberProfile? Profile { get; set; }
        public ICollection<MemberAddress> Addresses { get; set; } = new List<MemberAddress>();
        public ICollection<MemberDocument> Documents { get; set; } = new List<MemberDocument>();

        public string FullName => $"{FirstName} {LastName}";
        public int Age => DateTime.Today.Year - DateOfBirth.Year;
    }

    public class MemberProfile
    {
        public Guid Id { get; set; }
        public Guid MemberId { get; set; }
        public int? CreditScore { get; set; }
        public decimal? AnnualIncome { get; set; }
        public EmploymentStatus EmploymentStatus { get; set; }
        public string EmployerName { get; set; } = string.Empty;
        public string JobTitle { get; set; } = string.Empty;
        public DateTime? EmploymentStartDate { get; set; }
        public RiskLevel RiskLevel { get; set; }
        public DateTime LastUpdated { get; set; }

        // Navigation properties
        public Member Member { get; set; } = null!;
        public ICollection<GovernmentProgram> EligiblePrograms { get; set; } = new List<GovernmentProgram>();
    }

    public class GovernmentProgram
    {
        public Guid Id { get; set; }
        public string ProgramCode { get; set; } = string.Empty;
        public string ProgramName { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;
        public decimal? MaxLoanAmount { get; set; }
        public int? MinCreditScore { get; set; }
        public decimal? MaxIncomeLimit { get; set; }
        public bool IsActive { get; set; }
        public DateTime EffectiveDate { get; set; }
        public DateTime? ExpirationDate { get; set; }

        // Navigation properties
        public ICollection<MemberProfile> EligibleMembers { get; set; } = new List<MemberProfile>();
    }

    public class MemberAddress
    {
        public Guid Id { get; set; }
        public Guid MemberId { get; set; }
        public AddressType AddressType { get; set; }
        public string Street1 { get; set; } = string.Empty;
        public string Street2 { get; set; } = string.Empty;
        public string City { get; set; } = string.Empty;
        public string State { get; set; } = string.Empty;
        public string ZipCode { get; set; } = string.Empty;
        public string Country { get; set; } = "USA";
        public bool IsPrimary { get; set; }
        public DateTime CreatedAt { get; set; }

        // Navigation properties
        public Member Member { get; set; } = null!;
    }

    public class MemberDocument
    {
        public Guid Id { get; set; }
        public Guid MemberId { get; set; }
        public DocumentType DocumentType { get; set; }
        public string FileName { get; set; } = string.Empty;
        public string StoragePath { get; set; } = string.Empty;
        public long FileSize { get; set; }
        public string ContentType { get; set; } = string.Empty;
        public DateTime UploadedAt { get; set; }
        public string UploadedBy { get; set; } = string.Empty;

        // Navigation properties
        public Member Member { get; set; } = null!;
    }

    public enum MemberStatus
    {
        Active,
        Inactive,
        Suspended,
        Closed
    }

    public enum EmploymentStatus
    {
        Employed,
        SelfEmployed,
        Unemployed,
        Retired,
        Student
    }

    public enum RiskLevel
    {
        Low,
        Medium,
        High,
        Critical
    }

    public enum AddressType
    {
        Home,
        Mailing,
        Business
    }

    public enum DocumentType
    {
        DriverLicense,
        Passport,
        SSNCard,
        BirthCertificate,
        IncomeStatement,
        TaxReturn,
        BankStatement
    }
}