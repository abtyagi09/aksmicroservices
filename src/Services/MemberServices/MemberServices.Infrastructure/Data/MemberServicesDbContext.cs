using Microsoft.EntityFrameworkCore;
using MemberServices.Domain.Entities;
// using MemberServices.Domain.ValueObjects; // Commented out as ValueObjects don't exist yet
using Microsoft.EntityFrameworkCore.Storage.ValueConversion;

namespace MemberServices.Infrastructure.Data
{
    public class MemberServicesDbContext : DbContext
    {
        public MemberServicesDbContext(DbContextOptions<MemberServicesDbContext> options) : base(options) { }
        
        public DbSet<Member> Members { get; set; }
        public DbSet<MemberProfile> MemberProfiles { get; set; }
        public DbSet<GovernmentProgram> GovernmentPrograms { get; set; }
        
        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);
            
            // Configure Member entity
            modelBuilder.Entity<Member>(entity =>
            {
                entity.HasKey(e => e.Id);
                entity.Property(e => e.Id).ValueGeneratedOnAdd();
                entity.Property(e => e.MemberNumber).IsRequired().HasMaxLength(20);
                entity.Property(e => e.FirstName).IsRequired().HasMaxLength(100);
                entity.Property(e => e.LastName).IsRequired().HasMaxLength(100);
                entity.Property(e => e.Email).IsRequired().HasMaxLength(255);
                entity.Property(e => e.DateOfBirth).IsRequired();
                entity.Property(e => e.SSN).IsRequired().HasMaxLength(11);
                entity.Property(e => e.Status).HasConversion<string>().IsRequired();
                entity.Property(e => e.CreatedAt).IsRequired();
                entity.Property(e => e.UpdatedAt);
                
                entity.HasIndex(e => e.MemberNumber).IsUnique();
                entity.HasIndex(e => e.Email).IsUnique();
                entity.HasIndex(e => e.SSN).IsUnique();
                
                entity.HasOne(e => e.Profile)
                      .WithOne(p => p.Member)
                      .HasForeignKey<MemberProfile>(p => p.MemberId);
            });
            
            // Configure MemberProfile entity
            modelBuilder.Entity<MemberProfile>(entity =>
            {
                entity.HasKey(e => e.Id);
                entity.Property(e => e.Id).ValueGeneratedOnAdd();
                entity.Property(e => e.MemberId).IsRequired();
                entity.Property(e => e.CreditScore).HasPrecision(3, 0);
                entity.Property(e => e.AnnualIncome).HasPrecision(18, 2);
                entity.Property(e => e.EmploymentStatus).HasConversion<string>().IsRequired();
                entity.Property(e => e.RiskLevel).HasConversion<string>().IsRequired();
                
                entity.HasMany(e => e.EligiblePrograms)
                      .WithMany(p => p.EligibleMembers)
                      .UsingEntity("MemberProgramEligibility");
            });
            
            // Configure GovernmentProgram entity
            modelBuilder.Entity<GovernmentProgram>(entity =>
            {
                entity.HasKey(e => e.Id);
                entity.Property(e => e.Id).ValueGeneratedOnAdd();
                entity.Property(e => e.ProgramCode).IsRequired().HasMaxLength(20);
                entity.Property(e => e.ProgramName).IsRequired().HasMaxLength(200);
                entity.Property(e => e.Description).HasMaxLength(1000);
                entity.Property(e => e.MaxLoanAmount).HasPrecision(18, 2);
                entity.Property(e => e.MinCreditScore).HasPrecision(3, 0);
                entity.Property(e => e.MaxIncomeLimit).HasPrecision(18, 2);
                entity.Property(e => e.IsActive).IsRequired();
                
                entity.HasIndex(e => e.ProgramCode).IsUnique();
            });
            
            // Configure table names with schema
            modelBuilder.Entity<Member>().ToTable("Members", "member");
            modelBuilder.Entity<MemberProfile>().ToTable("MemberProfiles", "member");
            modelBuilder.Entity<GovernmentProgram>().ToTable("GovernmentPrograms", "member");
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