using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using MemberServices.Application.Services;
using MemberServices.Domain.Entities;
using MemberServices.Application.DTOs;

namespace MemberServices.API.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class MembersController : ControllerBase
    {
        private readonly IMemberService _memberService;
        private readonly ILogger<MembersController> _logger;

        public MembersController(IMemberService memberService, ILogger<MembersController> logger)
        {
            _memberService = memberService;
            _logger = logger;
        }

        [HttpGet]
        [ProducesResponseType(typeof(IEnumerable<MemberDto>), 200)]
        [ProducesResponseType(400)]
        public async Task<ActionResult<IEnumerable<MemberDto>>> GetMembers(
            [FromQuery] int page = 1, 
            [FromQuery] int size = 10,
            [FromQuery] string? search = null)
        {
            try
            {
                _logger.LogInformation("Retrieving members - Page: {Page}, Size: {Size}, Search: {Search}", 
                    page, size, search);

                var members = await _memberService.GetMembersAsync(page, size, search);
                return Ok(members);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error retrieving members");
                return BadRequest("An error occurred while retrieving members");
            }
        }

        [HttpGet("{id:guid}")]
        [ProducesResponseType(typeof(MemberDetailDto), 200)]
        [ProducesResponseType(404)]
        public async Task<ActionResult<MemberDetailDto>> GetMember(Guid id)
        {
            try
            {
                _logger.LogInformation("Retrieving member with ID: {MemberId}", id);

                var member = await _memberService.GetMemberByIdAsync(id);
                if (member == null)
                {
                    return NotFound($"Member with ID {id} not found");
                }

                return Ok(member);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error retrieving member {MemberId}", id);
                return BadRequest("An error occurred while retrieving the member");
            }
        }

        [HttpPost]
        [ProducesResponseType(typeof(MemberDto), 201)]
        [ProducesResponseType(400)]
        public async Task<ActionResult<MemberDto>> CreateMember([FromBody] CreateMemberDto createMemberDto)
        {
            try
            {
                _logger.LogInformation("Creating new member: {Email}", createMemberDto.Email);

                var member = await _memberService.CreateMemberAsync(createMemberDto);
                return CreatedAtAction(nameof(GetMember), new { id = member.Id }, member);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error creating member");
                return BadRequest("An error occurred while creating the member");
            }
        }

        [HttpPut("{id:guid}")]
        [ProducesResponseType(typeof(MemberDto), 200)]
        [ProducesResponseType(404)]
        [ProducesResponseType(400)]
        public async Task<ActionResult<MemberDto>> UpdateMember(Guid id, [FromBody] UpdateMemberDto updateMemberDto)
        {
            try
            {
                _logger.LogInformation("Updating member: {MemberId}", id);

                var member = await _memberService.UpdateMemberAsync(id, updateMemberDto);
                if (member == null)
                {
                    return NotFound($"Member with ID {id} not found");
                }

                return Ok(member);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error updating member {MemberId}", id);
                return BadRequest("An error occurred while updating the member");
            }
        }

        [HttpDelete("{id:guid}")]
        [ProducesResponseType(204)]
        [ProducesResponseType(404)]
        public async Task<ActionResult> DeleteMember(Guid id)
        {
            try
            {
                _logger.LogInformation("Deleting member: {MemberId}", id);

                var success = await _memberService.DeleteMemberAsync(id);
                if (!success)
                {
                    return NotFound($"Member with ID {id} not found");
                }

                return NoContent();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error deleting member {MemberId}", id);
                return BadRequest("An error occurred while deleting the member");
            }
        }

        [HttpGet("{id:guid}/eligibility")]
        [ProducesResponseType(typeof(IEnumerable<GovernmentProgramDto>), 200)]
        [ProducesResponseType(404)]
        public async Task<ActionResult<IEnumerable<GovernmentProgramDto>>> GetMemberEligibility(Guid id)
        {
            try
            {
                _logger.LogInformation("Retrieving eligibility for member: {MemberId}", id);

                var programs = await _memberService.GetEligibleProgramsAsync(id);
                return Ok(programs);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error retrieving eligibility for member {MemberId}", id);
                return BadRequest("An error occurred while retrieving eligibility information");
            }
        }

        [HttpPost("{id:guid}/verify")]
        [ProducesResponseType(typeof(MemberDto), 200)]
        [ProducesResponseType(404)]
        [ProducesResponseType(400)]
        public async Task<ActionResult<MemberDto>> VerifyMember(Guid id, [FromBody] VerifyMemberDto verifyMemberDto)
        {
            try
            {
                _logger.LogInformation("Verifying member: {MemberId}", id);

                var member = await _memberService.VerifyMemberAsync(id, verifyMemberDto);
                if (member == null)
                {
                    return NotFound($"Member with ID {id} not found");
                }

                return Ok(member);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error verifying member {MemberId}", id);
                return BadRequest("An error occurred while verifying the member");
            }
        }
    }

    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class GovernmentProgramsController : ControllerBase
    {
        private readonly IGovernmentProgramService _programService;
        private readonly ILogger<GovernmentProgramsController> _logger;

        public GovernmentProgramsController(IGovernmentProgramService programService, ILogger<GovernmentProgramsController> logger)
        {
            _programService = programService;
            _logger = logger;
        }

        [HttpGet]
        [ProducesResponseType(typeof(IEnumerable<GovernmentProgramDto>), 200)]
        public async Task<ActionResult<IEnumerable<GovernmentProgramDto>>> GetPrograms()
        {
            try
            {
                _logger.LogInformation("Retrieving all government programs");

                var programs = await _programService.GetActiveProgramsAsync();
                return Ok(programs);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error retrieving government programs");
                return BadRequest("An error occurred while retrieving government programs");
            }
        }

        [HttpGet("{id:guid}")]
        [ProducesResponseType(typeof(GovernmentProgramDto), 200)]
        [ProducesResponseType(404)]
        public async Task<ActionResult<GovernmentProgramDto>> GetProgram(Guid id)
        {
            try
            {
                _logger.LogInformation("Retrieving government program with ID: {ProgramId}", id);

                var program = await _programService.GetProgramByIdAsync(id);
                if (program == null)
                {
                    return NotFound($"Government program with ID {id} not found");
                }

                return Ok(program);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error retrieving government program {ProgramId}", id);
                return BadRequest("An error occurred while retrieving the government program");
            }
        }
    }
}