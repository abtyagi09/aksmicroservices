using Microsoft.EntityFrameworkCore;
using LoansUnderwriting.Domain.Entities;
using LoansUnderwriting.Domain.ValueObjects;
using Microsoft.EntityFrameworkCore.Storage.ValueConversion;

namespace LoansUnderwriting.Infrastructure.Data
{
    public class LoansUnderwritingDbContext : DbContext
    {
        public LoansUnderwritingDbContext(DbContextOptions<LoansUnderwritingDbContext> options) : base(options) { }
        
        public DbSet<LoanApplication> LoanApplications { get; set; }
        public DbSet<Loan> Loans { get; set; }
        public DbSet<UnderwritingDecision> UnderwritingDecisions { get; set; }
        public DbSet<Document> Documents { get; set; }
        public DbSet<CreditCheck> CreditChecks { get; set; }
        
        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);
            
            // Configure LoanApplication entity
            modelBuilder.Entity<LoanApplication>(entity =>
            {
                entity.HasKey(e => e.Id);
                entity.Property(e => e.Id).ValueGeneratedOnAdd();
                entity.Property(e => e.ApplicationNumber).IsRequired().HasMaxLength(20);
                entity.Property(e => e.MemberId).IsRequired();
                entity.Property(e => e.LoanAmount).HasPrecision(18, 2).IsRequired();
                entity.Property(e => e.LoanPurpose).IsRequired().HasMaxLength(500);
                entity.Property(e => e.RequestedTerm).IsRequired();
                entity.Property(e => e.Status).HasConversion<string>().IsRequired();
                entity.Property(e => e.ProgramCode).IsRequired().HasMaxLength(20);
                entity.Property(e => e.SubmissionDate).IsRequired();
                entity.Property(e => e.LastUpdated).IsRequired();
                
                entity.HasIndex(e => e.ApplicationNumber).IsUnique();
                entity.HasIndex(e => e.MemberId);
                entity.HasIndex(e => new { e.Status, e.SubmissionDate });
                
                entity.HasMany(e => e.Documents)
                      .WithOne(d => d.LoanApplication)
                      .HasForeignKey(d => d.LoanApplicationId);
                      
                entity.HasMany(e => e.CreditChecks)
                      .WithOne(c => c.LoanApplication)
                      .HasForeignKey(c => c.LoanApplicationId);
            });
            
            // Configure Loan entity
            modelBuilder.Entity<Loan>(entity =>
            {
                entity.HasKey(e => e.Id);
                entity.Property(e => e.Id).ValueGeneratedOnAdd();
                entity.Property(e => e.LoanNumber).IsRequired().HasMaxLength(20);
                entity.Property(e => e.ApplicationId).IsRequired();
                entity.Property(e => e.PrincipalAmount).HasPrecision(18, 2).IsRequired();
                entity.Property(e => e.InterestRate).HasPrecision(5, 4).IsRequired();
                entity.Property(e => e.TermInMonths).IsRequired();
                entity.Property(e => e.MonthlyPayment).HasPrecision(18, 2).IsRequired();
                entity.Property(e => e.Status).HasConversion<string>().IsRequired();
                entity.Property(e => e.OriginationDate).IsRequired();
                entity.Property(e => e.MaturityDate).IsRequired();
                entity.Property(e => e.CurrentBalance).HasPrecision(18, 2).IsRequired();
                
                entity.HasIndex(e => e.LoanNumber).IsUnique();
                entity.HasIndex(e => e.ApplicationId).IsUnique();
                entity.HasIndex(e => e.Status);
                
                entity.HasOne(e => e.Application)
                      .WithOne(a => a.Loan)
                      .HasForeignKey<Loan>(l => l.ApplicationId);
            });
            
            // Configure UnderwritingDecision entity
            modelBuilder.Entity<UnderwritingDecision>(entity =>
            {
                entity.HasKey(e => e.Id);
                entity.Property(e => e.Id).ValueGeneratedOnAdd();
                entity.Property(e => e.ApplicationId).IsRequired();
                entity.Property(e => e.Decision).HasConversion<string>().IsRequired();
                entity.Property(e => e.DecisionReason).HasMaxLength(1000);
                entity.Property(e => e.UnderwriterId).IsRequired().HasMaxLength(50);
                entity.Property(e => e.DecisionDate).IsRequired();
                entity.Property(e => e.RiskScore).HasPrecision(5, 2);
                entity.Property(e => e.DebtToIncomeRatio).HasPrecision(5, 4);
                
                entity.HasIndex(e => e.ApplicationId);
                entity.HasIndex(e => new { e.Decision, e.DecisionDate });
                
                entity.HasOne(e => e.LoanApplication)
                      .WithMany(a => a.UnderwritingDecisions)
                      .HasForeignKey(e => e.ApplicationId);
            });
            
            // Configure Document entity
            modelBuilder.Entity<Document>(entity =>
            {
                entity.HasKey(e => e.Id);
                entity.Property(e => e.Id).ValueGeneratedOnAdd();
                entity.Property(e => e.LoanApplicationId).IsRequired();
                entity.Property(e => e.DocumentType).HasConversion<string>().IsRequired();
                entity.Property(e => e.FileName).IsRequired().HasMaxLength(255);
                entity.Property(e => e.FileSize).IsRequired();
                entity.Property(e => e.MimeType).IsRequired().HasMaxLength(100);
                entity.Property(e => e.StoragePath).IsRequired().HasMaxLength(500);
                entity.Property(e => e.UploadedAt).IsRequired();
                entity.Property(e => e.UploadedBy).IsRequired().HasMaxLength(50);
                
                entity.HasIndex(e => e.LoanApplicationId);
                entity.HasIndex(e => e.DocumentType);
            });
            
            // Configure CreditCheck entity
            modelBuilder.Entity<CreditCheck>(entity =>
            {
                entity.HasKey(e => e.Id);
                entity.Property(e => e.Id).ValueGeneratedOnAdd();
                entity.Property(e => e.LoanApplicationId).IsRequired();
                entity.Property(e => e.CreditBureau).IsRequired().HasMaxLength(50);
                entity.Property(e => e.CreditScore).HasPrecision(3, 0).IsRequired();
                entity.Property(e => e.CheckDate).IsRequired();
                entity.Property(e => e.ReportData).HasColumnType("nvarchar(max)");
                
                entity.HasIndex(e => e.LoanApplicationId);
                entity.HasIndex(e => e.CheckDate);
            });
            
            // Configure table names with schema
            modelBuilder.Entity<LoanApplication>().ToTable("LoanApplications", "loans");
            modelBuilder.Entity<Loan>().ToTable("Loans", "loans");
            modelBuilder.Entity<UnderwritingDecision>().ToTable("UnderwritingDecisions", "loans");
            modelBuilder.Entity<Document>().ToTable("Documents", "loans");
            modelBuilder.Entity<CreditCheck>().ToTable("CreditChecks", "loans");
        }
        
        protected override void OnConfiguring(DbContextOptionsBuilder optionsBuilder)
        {
            if (!optionsBuilder.IsConfigured)
            {
                optionsBuilder.EnableSensitiveDataLogging(false)
                             .EnableServiceProviderCaching()
                             .EnableDetailedErrors();
            }
        }
    }
}