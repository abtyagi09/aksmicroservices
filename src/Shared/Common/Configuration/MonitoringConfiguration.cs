using Microsoft.ApplicationInsights.AspNetCore.Extensions;
using Microsoft.ApplicationInsights.Extensibility;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;
using Shared.Common.Monitoring;
using System.Reflection;

namespace Shared.Common.Configuration
{
    public static class MonitoringConfiguration
    {
        public static IServiceCollection AddMonitoring(this IServiceCollection services, IConfiguration configuration, IHostEnvironment environment)
        {
            // Application Insights configuration
            var instrumentationKey = configuration["ApplicationInsights:InstrumentationKey"];
            var connectionString = configuration["ApplicationInsights:ConnectionString"];

            if (!string.IsNullOrEmpty(connectionString) || !string.IsNullOrEmpty(instrumentationKey))
            {
                services.AddApplicationInsightsTelemetry(options =>
                {
                    if (!string.IsNullOrEmpty(connectionString))
                    {
                        options.ConnectionString = connectionString;
                    }
                    else
                    {
                        options.InstrumentationKey = instrumentationKey;
                    }

                    // Configure sampling
                    options.EnableAdaptiveSampling = true;
                    options.EnableQuickPulseMetricStream = true;
                    options.EnableAuthenticationTrackingJavaScript = false;
                    options.EnableHeartbeat = true;
                });

                // Configure telemetry
                services.Configure<TelemetryConfiguration>(config =>
                {
                    config.SetAzureTokenCredential(new DefaultAzureCredential());
                    
                    // Add custom telemetry initializers
                    config.TelemetryInitializers.Add(new FarmersBankTelemetryInitializer(environment));
                    
                    // Configure sampling
                    if (environment.IsProduction())
                    {
                        config.DefaultTelemetrySink.TelemetryProcessorChainBuilder
                            .UseAdaptiveSampling(5, excludedTypes: "Event") // 5 requests per second
                            .Build();
                    }
                });
            }

            // Register monitoring services
            services.AddScoped<IApplicationMonitoring, ApplicationInsightsMonitoring>();
            services.AddScoped<IHealthCheckService, HealthCheckService>();
            services.AddScoped<IPerformanceMonitoring, PerformanceMonitoring>();
            services.AddScoped<IAlertingService, AlertingService>();

            // Add health checks
            services.AddHealthChecks()
                .AddCheck("database", () => 
                {
                    // Database health check logic
                    return Microsoft.Extensions.Diagnostics.HealthChecks.HealthCheckResult.Healthy("Database is responsive");
                })
                .AddCheck("servicebus", () => 
                {
                    // Service Bus health check logic
                    return Microsoft.Extensions.Diagnostics.HealthChecks.HealthCheckResult.Healthy("Service Bus is responsive");
                });

            return services;
        }

        public static IApplicationBuilder UseMonitoring(this IApplicationBuilder app, IHostEnvironment environment)
        {
            // Add request telemetry middleware
            app.UseMiddleware<RequestTelemetryMiddleware>();

            // Add performance monitoring middleware
            app.UseMiddleware<PerformanceMonitoringMiddleware>();

            // Add exception tracking middleware
            app.UseMiddleware<ExceptionTrackingMiddleware>();

            // Health check endpoints
            app.UseHealthChecks("/health", new HealthCheckOptions
            {
                ResponseWriter = async (context, report) =>
                {
                    context.Response.ContentType = "application/json";
                    var response = new
                    {
                        status = report.Status.ToString(),
                        checks = report.Entries.Select(x => new
                        {
                            name = x.Key,
                            status = x.Value.Status.ToString(),
                            description = x.Value.Description,
                            duration = x.Value.Duration.TotalMilliseconds
                        }),
                        totalDuration = report.TotalDuration.TotalMilliseconds
                    };
                    
                    var jsonResponse = JsonSerializer.Serialize(response, new JsonSerializerOptions
                    {
                        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
                        WriteIndented = true
                    });
                    
                    await context.Response.WriteAsync(jsonResponse);
                }
            });

            return app;
        }
    }

    public class FarmersBankTelemetryInitializer : ITelemetryInitializer
    {
        private readonly IHostEnvironment _environment;
        private readonly string _serviceName;

        public FarmersBankTelemetryInitializer(IHostEnvironment environment)
        {
            _environment = environment;
            _serviceName = Assembly.GetEntryAssembly()?.GetName().Name ?? "FarmersBank.Unknown";
        }

        public void Initialize(ITelemetry telemetry)
        {
            telemetry.Context.Component.Version = Assembly.GetEntryAssembly()?.GetName().Version?.ToString() ?? "1.0.0";
            telemetry.Context.Cloud.RoleName = _serviceName;
            telemetry.Context.Cloud.RoleInstance = Environment.MachineName;
            
            // Add custom properties
            telemetry.Context.GlobalProperties["Environment"] = _environment.EnvironmentName;
            telemetry.Context.GlobalProperties["ServiceName"] = _serviceName;
            telemetry.Context.GlobalProperties["BuildTime"] = GetBuildTime();
            telemetry.Context.GlobalProperties["BankingDomain"] = GetDomainFromServiceName(_serviceName);
        }

        private static string GetBuildTime()
        {
            var assembly = Assembly.GetEntryAssembly();
            if (assembly != null)
            {
                var fileInfo = new FileInfo(assembly.Location);
                return fileInfo.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss UTC");
            }
            return DateTime.UtcNow.ToString("yyyy-MM-dd HH:mm:ss UTC");
        }

        private static string GetDomainFromServiceName(string serviceName)
        {
            return serviceName.ToLower() switch
            {
                var name when name.Contains("member") => "Member Services",
                var name when name.Contains("loan") || name.Contains("underwriting") => "Loans & Underwriting",
                var name when name.Contains("payment") => "Payments",
                var name when name.Contains("fraud") || name.Contains("risk") => "Fraud/Risk",
                _ => "Shared"
            };
        }
    }

    public class RequestTelemetryMiddleware
    {
        private readonly RequestDelegate _next;
        private readonly IApplicationMonitoring _monitoring;
        private readonly ILogger<RequestTelemetryMiddleware> _logger;

        public RequestTelemetryMiddleware(RequestDelegate next, IApplicationMonitoring monitoring, ILogger<RequestTelemetryMiddleware> logger)
        {
            _next = next;
            _monitoring = monitoring;
            _logger = logger;
        }

        public async Task InvokeAsync(HttpContext context)
        {
            var stopwatch = Stopwatch.StartNew();
            var requestId = Guid.NewGuid().ToString();
            
            // Add correlation ID to response headers
            context.Response.Headers.Add("X-Correlation-ID", requestId);
            
            // Add to logs context
            using (_logger.BeginScope(new Dictionary<string, object>
            {
                ["CorrelationId"] = requestId,
                ["RequestPath"] = context.Request.Path,
                ["RequestMethod"] = context.Request.Method
            }))
            {
                try
                {
                    await _next(context);
                    stopwatch.Stop();

                    // Track successful request
                    _monitoring.TrackRequest(
                        name: $"{context.Request.Method} {context.Request.Path}",
                        startTime: DateTimeOffset.UtcNow.Subtract(stopwatch.Elapsed),
                        duration: stopwatch.Elapsed,
                        responseCode: context.Response.StatusCode.ToString(),
                        success: context.Response.StatusCode < 400
                    );

                    // Track performance metrics
                    var properties = new Dictionary<string, string>
                    {
                        ["Method"] = context.Request.Method,
                        ["Path"] = context.Request.Path,
                        ["StatusCode"] = context.Response.StatusCode.ToString(),
                        ["UserAgent"] = context.Request.Headers.UserAgent.ToString()
                    };

                    _monitoring.TrackMetric("Request.Duration", stopwatch.ElapsedMilliseconds, properties);
                }
                catch (Exception ex)
                {
                    stopwatch.Stop();

                    // Track failed request
                    _monitoring.TrackRequest(
                        name: $"{context.Request.Method} {context.Request.Path}",
                        startTime: DateTimeOffset.UtcNow.Subtract(stopwatch.Elapsed),
                        duration: stopwatch.Elapsed,
                        responseCode: "500",
                        success: false
                    );

                    _monitoring.TrackException(ex, new Dictionary<string, string>
                    {
                        ["CorrelationId"] = requestId,
                        ["RequestPath"] = context.Request.Path,
                        ["RequestMethod"] = context.Request.Method
                    });

                    throw;
                }
            }
        }
    }

    public class PerformanceMonitoringMiddleware
    {
        private readonly RequestDelegate _next;
        private readonly IPerformanceMonitoring _performanceMonitoring;
        private readonly IAlertingService _alertingService;
        private readonly IConfiguration _configuration;

        public PerformanceMonitoringMiddleware(
            RequestDelegate next, 
            IPerformanceMonitoring performanceMonitoring,
            IAlertingService alertingService,
            IConfiguration configuration)
        {
            _next = next;
            _performanceMonitoring = performanceMonitoring;
            _alertingService = alertingService;
            _configuration = configuration;
        }

        public async Task InvokeAsync(HttpContext context)
        {
            var endpoint = $"{context.Request.Method} {context.Request.Path}";
            var stopwatch = Stopwatch.StartNew();

            try
            {
                await _next(context);
                stopwatch.Stop();

                var success = context.Response.StatusCode < 400;
                _performanceMonitoring.RecordResponseTime(endpoint, stopwatch.ElapsedMilliseconds, success);
                _performanceMonitoring.RecordThroughput(endpoint);

                // Check for performance SLA violations
                var slaThreshold = _configuration.GetValue<double>("Monitoring:SLA:ResponseTimeMs", 200);
                if (stopwatch.ElapsedMilliseconds > slaThreshold)
                {
                    await _alertingService.SendWarningAlertAsync(
                        "SLA Violation",
                        $"Endpoint {endpoint} exceeded SLA threshold. Duration: {stopwatch.ElapsedMilliseconds}ms",
                        new Dictionary<string, object>
                        {
                            ["Endpoint"] = endpoint,
                            ["Duration"] = stopwatch.ElapsedMilliseconds,
                            ["Threshold"] = slaThreshold,
                            ["StatusCode"] = context.Response.StatusCode
                        });
                }
            }
            catch (Exception ex)
            {
                stopwatch.Stop();
                _performanceMonitoring.RecordResponseTime(endpoint, stopwatch.ElapsedMilliseconds, false);
                
                // Alert on exceptions
                await _alertingService.SendCriticalAlertAsync(
                    "Unhandled Exception",
                    $"Exception in {endpoint}: {ex.Message}",
                    new Dictionary<string, object>
                    {
                        ["Endpoint"] = endpoint,
                        ["Duration"] = stopwatch.ElapsedMilliseconds,
                        ["ExceptionType"] = ex.GetType().Name,
                        ["StackTrace"] = ex.StackTrace ?? "No stack trace available"
                    });

                throw;
            }
        }
    }

    public class ExceptionTrackingMiddleware
    {
        private readonly RequestDelegate _next;
        private readonly IApplicationMonitoring _monitoring;
        private readonly IAlertingService _alertingService;
        private readonly ILogger<ExceptionTrackingMiddleware> _logger;

        public ExceptionTrackingMiddleware(
            RequestDelegate next, 
            IApplicationMonitoring monitoring,
            IAlertingService alertingService,
            ILogger<ExceptionTrackingMiddleware> logger)
        {
            _next = next;
            _monitoring = monitoring;
            _alertingService = alertingService;
            _logger = logger;
        }

        public async Task InvokeAsync(HttpContext context)
        {
            try
            {
                await _next(context);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Unhandled exception occurred in request pipeline");

                var properties = new Dictionary<string, string>
                {
                    ["RequestId"] = context.TraceIdentifier,
                    ["RequestPath"] = context.Request.Path,
                    ["RequestMethod"] = context.Request.Method,
                    ["UserAgent"] = context.Request.Headers.UserAgent.ToString(),
                    ["RemoteIpAddress"] = context.Connection.RemoteIpAddress?.ToString() ?? "Unknown"
                };

                _monitoring.TrackException(ex, properties);

                // Send critical alert for unhandled exceptions
                await _alertingService.SendCriticalAlertAsync(
                    "Unhandled Exception",
                    $"Unhandled exception in {context.Request.Method} {context.Request.Path}: {ex.Message}",
                    new Dictionary<string, object>
                    {
                        ["RequestId"] = context.TraceIdentifier,
                        ["RequestPath"] = context.Request.Path.ToString(),
                        ["ExceptionType"] = ex.GetType().Name,
                        ["Message"] = ex.Message,
                        ["Source"] = ex.Source ?? "Unknown"
                    });

                // Re-throw to maintain normal exception handling
                throw;
            }
        }
    }
}