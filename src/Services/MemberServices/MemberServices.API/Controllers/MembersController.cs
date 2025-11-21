using Microsoft.AspNetCore.Mvc;

namespace MemberServices.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class MembersController : ControllerBase
{
    [HttpGet]
    public IActionResult Get()
    {
        var members = new[]
        {
            new { Id = 1, Name = "John Farmer", AccountType = "Premium", LoanEligible = true },
            new { Id = 2, Name = "Jane Agriculture", AccountType = "Standard", LoanEligible = true },
            new { Id = 3, Name = "Bob Rancher", AccountType = "Premium", LoanEligible = false }
        };
        return Ok(new { 
            Message = "Farmers Bank Member Services API", 
            Members = members,
            Service = "Member Services",
            Version = "1.0",
            Timestamp = DateTime.UtcNow 
        });
    }

    [HttpGet("health")]
    public IActionResult Health()
    {
        return Ok(new { 
            Status = "Healthy", 
            Service = "Member Services", 
            Timestamp = DateTime.UtcNow,
            Version = "1.0.0"
        });
    }

    [HttpGet("{id}")]
    public IActionResult GetMember(int id)
    {
        var member = new { 
            Id = id, 
            Name = $"Member {id}", 
            AccountType = "Standard",
            JoinDate = DateTime.UtcNow.AddYears(-2),
            Status = "Active"
        };
        return Ok(member);
    }
}