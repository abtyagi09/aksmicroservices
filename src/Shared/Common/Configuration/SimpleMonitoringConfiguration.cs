using Microsoft.Extensions.DependencyInjection;
using Microsoft.AspNetCore.Builder;

namespace Shared.Common.Configuration
{
    /// <summary>
    /// Simple configuration class for basic health checks
    /// </summary>
    public static class SimpleMonitoringConfiguration
    {
        /// <summary>
        /// Add basic health checks to the service collection
        /// </summary>
        public static IServiceCollection AddBasicHealthChecks(this IServiceCollection services)
        {
            services.AddHealthChecks()
                .AddCheck("api", () => Microsoft.Extensions.Diagnostics.HealthChecks.HealthCheckResult.Healthy("API is running"));

            return services;
        }

        /// <summary>
        /// Configure basic health check endpoints
        /// </summary>
        public static IApplicationBuilder UseBasicHealthChecks(this IApplicationBuilder app)
        {
            app.UseHealthChecks("/health");
            return app;
        }
    }
}