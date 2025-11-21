using Microsoft.ApplicationInsights;
using Microsoft.ApplicationInsights.DataContracts;
using Microsoft.Extensions.Logging;
using System.Diagnostics;

namespace Shared.Common.Monitoring
{
    public interface IApplicationMonitoring
    {
        void TrackEvent(string eventName, Dictionary<string, string>? properties = null, Dictionary<string, double>? metrics = null);
        void TrackException(Exception exception, Dictionary<string, string>? properties = null);
        void TrackDependency(string dependencyTypeName, string target, string dependencyName, string data, DateTimeOffset startTime, TimeSpan duration, bool success);
        void TrackRequest(string name, DateTimeOffset startTime, TimeSpan duration, string responseCode, bool success);
        void TrackMetric(string name, double value, Dictionary<string, string>? properties = null);
        void TrackTrace(string message, SeverityLevel severityLevel = SeverityLevel.Information, Dictionary<string, string>? properties = null);
        IDisposable StartOperation(string operationName, string? operationId = null);
    }

    public class ApplicationInsightsMonitoring : IApplicationMonitoring
    {
        private readonly TelemetryClient _telemetryClient;
        private readonly ILogger<ApplicationInsightsMonitoring> _logger;

        public ApplicationInsightsMonitoring(TelemetryClient telemetryClient, ILogger<ApplicationInsightsMonitoring> logger)
        {
            _telemetryClient = telemetryClient;
            _logger = logger;
        }

        public void TrackEvent(string eventName, Dictionary<string, string>? properties = null, Dictionary<string, double>? metrics = null)
        {
            try
            {
                _telemetryClient.TrackEvent(eventName, properties, metrics);
                _logger.LogInformation("Event tracked: {EventName}", eventName);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to track event: {EventName}", eventName);
            }
        }

        public void TrackException(Exception exception, Dictionary<string, string>? properties = null)
        {
            try
            {
                _telemetryClient.TrackException(exception, properties);
                _logger.LogError(exception, "Exception tracked");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to track exception");
            }
        }

        public void TrackDependency(string dependencyTypeName, string target, string dependencyName, string data, DateTimeOffset startTime, TimeSpan duration, bool success)
        {
            try
            {
                _telemetryClient.TrackDependency(dependencyTypeName, target, dependencyName, data, startTime, duration, success);
                _logger.LogDebug("Dependency tracked: {DependencyName} - Success: {Success}, Duration: {Duration}ms", 
                    dependencyName, success, duration.TotalMilliseconds);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to track dependency: {DependencyName}", dependencyName);
            }
        }

        public void TrackRequest(string name, DateTimeOffset startTime, TimeSpan duration, string responseCode, bool success)
        {
            try
            {
                _telemetryClient.TrackRequest(name, startTime, duration, responseCode, success);
                _logger.LogDebug("Request tracked: {RequestName} - Code: {ResponseCode}, Duration: {Duration}ms", 
                    name, responseCode, duration.TotalMilliseconds);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to track request: {RequestName}", name);
            }
        }

        public void TrackMetric(string name, double value, Dictionary<string, string>? properties = null)
        {
            try
            {
                _telemetryClient.TrackMetric(name, value, properties);
                _logger.LogDebug("Metric tracked: {MetricName} = {Value}", name, value);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to track metric: {MetricName}", name);
            }
        }

        public void TrackTrace(string message, SeverityLevel severityLevel = SeverityLevel.Information, Dictionary<string, string>? properties = null)
        {
            try
            {
                _telemetryClient.TrackTrace(message, severityLevel, properties);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to track trace message");
            }
        }

        public IDisposable StartOperation(string operationName, string? operationId = null)
        {
            try
            {
                var operation = _telemetryClient.StartOperation<RequestTelemetry>(operationName);
                if (!string.IsNullOrEmpty(operationId))
                {
                    operation.Telemetry.Id = operationId;
                }
                return operation;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to start operation: {OperationName}", operationName);
                return new NoOpDisposable();
            }
        }

        private class NoOpDisposable : IDisposable
        {
            public void Dispose() { }
        }
    }

    public interface IHealthCheckService
    {
        Task<HealthCheckResult> CheckDatabaseHealthAsync();
        Task<HealthCheckResult> CheckServiceBusHealthAsync();
        Task<HealthCheckResult> CheckExternalServiceHealthAsync(string serviceName, string endpoint);
        Task<HealthCheckResult> CheckOverallHealthAsync();
    }

    public class HealthCheckService : IHealthCheckService
    {
        private readonly IServiceProvider _serviceProvider;
        private readonly ILogger<HealthCheckService> _logger;
        private readonly IApplicationMonitoring _monitoring;

        public HealthCheckService(IServiceProvider serviceProvider, ILogger<HealthCheckService> logger, IApplicationMonitoring monitoring)
        {
            _serviceProvider = serviceProvider;
            _logger = logger;
            _monitoring = monitoring;
        }

        public async Task<HealthCheckResult> CheckDatabaseHealthAsync()
        {
            var stopwatch = Stopwatch.StartNew();
            try
            {
                // Check database connectivity
                using var scope = _serviceProvider.CreateScope();
                var dbContext = scope.ServiceProvider.GetRequiredService<DbContext>();
                
                await dbContext.Database.CanConnectAsync();
                
                stopwatch.Stop();
                
                var result = new HealthCheckResult
                {
                    IsHealthy = true,
                    ResponseTime = stopwatch.Elapsed,
                    Message = "Database connection successful",
                    CheckedAt = DateTime.UtcNow
                };

                _monitoring.TrackMetric("HealthCheck.Database.ResponseTime", stopwatch.ElapsedMilliseconds);
                _monitoring.TrackMetric("HealthCheck.Database.Status", 1); // 1 = healthy, 0 = unhealthy

                return result;
            }
            catch (Exception ex)
            {
                stopwatch.Stop();
                _logger.LogError(ex, "Database health check failed");
                
                _monitoring.TrackException(ex, new Dictionary<string, string> { { "HealthCheck", "Database" } });
                _monitoring.TrackMetric("HealthCheck.Database.Status", 0);

                return new HealthCheckResult
                {
                    IsHealthy = false,
                    ResponseTime = stopwatch.Elapsed,
                    Message = $"Database connection failed: {ex.Message}",
                    CheckedAt = DateTime.UtcNow,
                    Exception = ex
                };
            }
        }

        public async Task<HealthCheckResult> CheckServiceBusHealthAsync()
        {
            var stopwatch = Stopwatch.StartNew();
            try
            {
                // Check Service Bus connectivity
                // Implementation depends on your Service Bus client setup
                await Task.Delay(100); // Simulate health check
                
                stopwatch.Stop();

                var result = new HealthCheckResult
                {
                    IsHealthy = true,
                    ResponseTime = stopwatch.Elapsed,
                    Message = "Service Bus connection successful",
                    CheckedAt = DateTime.UtcNow
                };

                _monitoring.TrackMetric("HealthCheck.ServiceBus.ResponseTime", stopwatch.ElapsedMilliseconds);
                _monitoring.TrackMetric("HealthCheck.ServiceBus.Status", 1);

                return result;
            }
            catch (Exception ex)
            {
                stopwatch.Stop();
                _logger.LogError(ex, "Service Bus health check failed");
                
                _monitoring.TrackException(ex, new Dictionary<string, string> { { "HealthCheck", "ServiceBus" } });
                _monitoring.TrackMetric("HealthCheck.ServiceBus.Status", 0);

                return new HealthCheckResult
                {
                    IsHealthy = false,
                    ResponseTime = stopwatch.Elapsed,
                    Message = $"Service Bus connection failed: {ex.Message}",
                    CheckedAt = DateTime.UtcNow,
                    Exception = ex
                };
            }
        }

        public async Task<HealthCheckResult> CheckExternalServiceHealthAsync(string serviceName, string endpoint)
        {
            var stopwatch = Stopwatch.StartNew();
            try
            {
                using var httpClient = new HttpClient { Timeout = TimeSpan.FromSeconds(10) };
                var response = await httpClient.GetAsync(endpoint);
                
                stopwatch.Stop();

                var result = new HealthCheckResult
                {
                    IsHealthy = response.IsSuccessStatusCode,
                    ResponseTime = stopwatch.Elapsed,
                    Message = $"{serviceName} health check - Status: {response.StatusCode}",
                    CheckedAt = DateTime.UtcNow
                };

                _monitoring.TrackMetric($"HealthCheck.{serviceName}.ResponseTime", stopwatch.ElapsedMilliseconds);
                _monitoring.TrackMetric($"HealthCheck.{serviceName}.Status", response.IsSuccessStatusCode ? 1 : 0);

                return result;
            }
            catch (Exception ex)
            {
                stopwatch.Stop();
                _logger.LogError(ex, "External service health check failed for {ServiceName}", serviceName);
                
                _monitoring.TrackException(ex, new Dictionary<string, string> 
                { 
                    { "HealthCheck", serviceName },
                    { "Endpoint", endpoint }
                });
                _monitoring.TrackMetric($"HealthCheck.{serviceName}.Status", 0);

                return new HealthCheckResult
                {
                    IsHealthy = false,
                    ResponseTime = stopwatch.Elapsed,
                    Message = $"{serviceName} health check failed: {ex.Message}",
                    CheckedAt = DateTime.UtcNow,
                    Exception = ex
                };
            }
        }

        public async Task<HealthCheckResult> CheckOverallHealthAsync()
        {
            var healthChecks = new List<Task<HealthCheckResult>>
            {
                CheckDatabaseHealthAsync(),
                CheckServiceBusHealthAsync()
            };

            var results = await Task.WhenAll(healthChecks);
            var allHealthy = results.All(r => r.IsHealthy);
            var maxResponseTime = results.Max(r => r.ResponseTime);

            return new HealthCheckResult
            {
                IsHealthy = allHealthy,
                ResponseTime = maxResponseTime,
                Message = allHealthy ? "All systems healthy" : "Some systems are unhealthy",
                CheckedAt = DateTime.UtcNow,
                Details = results.ToDictionary(r => r.Message ?? "Unknown", r => r.IsHealthy)
            };
        }
    }

    public class HealthCheckResult
    {
        public bool IsHealthy { get; set; }
        public TimeSpan ResponseTime { get; set; }
        public string? Message { get; set; }
        public DateTime CheckedAt { get; set; }
        public Exception? Exception { get; set; }
        public Dictionary<string, object>? Details { get; set; }
    }

    public interface IPerformanceMonitoring
    {
        IDisposable StartPerformanceCounter(string operationName);
        void RecordPerformanceMetric(string metricName, double value, string? unit = null);
        void RecordResponseTime(string endpoint, double milliseconds, bool success = true);
        void RecordThroughput(string operationName, int count = 1);
    }

    public class PerformanceMonitoring : IPerformanceMonitoring
    {
        private readonly IApplicationMonitoring _monitoring;
        private readonly ILogger<PerformanceMonitoring> _logger;

        public PerformanceMonitoring(IApplicationMonitoring monitoring, ILogger<PerformanceMonitoring> logger)
        {
            _monitoring = monitoring;
            _logger = logger;
        }

        public IDisposable StartPerformanceCounter(string operationName)
        {
            return new PerformanceCounter(operationName, _monitoring, _logger);
        }

        public void RecordPerformanceMetric(string metricName, double value, string? unit = null)
        {
            var properties = unit != null ? new Dictionary<string, string> { { "unit", unit } } : null;
            _monitoring.TrackMetric($"Performance.{metricName}", value, properties);
        }

        public void RecordResponseTime(string endpoint, double milliseconds, bool success = true)
        {
            var properties = new Dictionary<string, string>
            {
                { "endpoint", endpoint },
                { "success", success.ToString() }
            };
            
            _monitoring.TrackMetric("Performance.ResponseTime", milliseconds, properties);
            
            // Track SLA compliance (assuming 200ms SLA)
            var slaCompliant = milliseconds <= 200;
            _monitoring.TrackMetric("Performance.SLA.Compliance", slaCompliant ? 1 : 0, properties);
        }

        public void RecordThroughput(string operationName, int count = 1)
        {
            var properties = new Dictionary<string, string> { { "operation", operationName } };
            _monitoring.TrackMetric("Performance.Throughput", count, properties);
        }

        private class PerformanceCounter : IDisposable
        {
            private readonly string _operationName;
            private readonly IApplicationMonitoring _monitoring;
            private readonly ILogger _logger;
            private readonly Stopwatch _stopwatch;
            private bool _disposed = false;

            public PerformanceCounter(string operationName, IApplicationMonitoring monitoring, ILogger logger)
            {
                _operationName = operationName;
                _monitoring = monitoring;
                _logger = logger;
                _stopwatch = Stopwatch.StartNew();
            }

            public void Dispose()
            {
                if (!_disposed)
                {
                    _stopwatch.Stop();
                    var duration = _stopwatch.ElapsedMilliseconds;
                    
                    _monitoring.TrackMetric($"Performance.Operation.{_operationName}", duration);
                    _logger.LogDebug("Operation {OperationName} completed in {Duration}ms", _operationName, duration);
                    
                    _disposed = true;
                }
            }
        }
    }

    public interface IAlertingService
    {
        Task SendCriticalAlertAsync(string title, string message, Dictionary<string, object>? metadata = null);
        Task SendWarningAlertAsync(string title, string message, Dictionary<string, object>? metadata = null);
        Task SendInfoAlertAsync(string title, string message, Dictionary<string, object>? metadata = null);
        Task SendHealthCheckAlertAsync(HealthCheckResult healthCheckResult);
    }

    public class AlertingService : IAlertingService
    {
        private readonly IApplicationMonitoring _monitoring;
        private readonly ILogger<AlertingService> _logger;
        private readonly IConfiguration _configuration;

        public AlertingService(IApplicationMonitoring monitoring, ILogger<AlertingService> logger, IConfiguration configuration)
        {
            _monitoring = monitoring;
            _logger = logger;
            _configuration = configuration;
        }

        public async Task SendCriticalAlertAsync(string title, string message, Dictionary<string, object>? metadata = null)
        {
            await SendAlertAsync("CRITICAL", title, message, metadata);
        }

        public async Task SendWarningAlertAsync(string title, string message, Dictionary<string, object>? metadata = null)
        {
            await SendAlertAsync("WARNING", title, message, metadata);
        }

        public async Task SendInfoAlertAsync(string title, string message, Dictionary<string, object>? metadata = null)
        {
            await SendAlertAsync("INFO", title, message, metadata);
        }

        public async Task SendHealthCheckAlertAsync(HealthCheckResult healthCheckResult)
        {
            if (!healthCheckResult.IsHealthy)
            {
                var metadata = new Dictionary<string, object>
                {
                    { "ResponseTime", healthCheckResult.ResponseTime.TotalMilliseconds },
                    { "CheckedAt", healthCheckResult.CheckedAt },
                    { "Exception", healthCheckResult.Exception?.ToString() ?? "None" }
                };

                await SendCriticalAlertAsync(
                    "Health Check Failed",
                    healthCheckResult.Message ?? "Health check failed without specific message",
                    metadata);
            }
        }

        private async Task SendAlertAsync(string severity, string title, string message, Dictionary<string, object>? metadata = null)
        {
            try
            {
                // Log the alert
                _logger.LogWarning("Alert {Severity}: {Title} - {Message}", severity, title, message);

                // Track as custom event
                var properties = new Dictionary<string, string>
                {
                    { "severity", severity },
                    { "title", title },
                    { "message", message }
                };

                if (metadata != null)
                {
                    foreach (var kvp in metadata)
                    {
                        properties[$"metadata_{kvp.Key}"] = kvp.Value?.ToString() ?? "null";
                    }
                }

                _monitoring.TrackEvent("Alert.Sent", properties);

                // Send to external alerting systems (Teams, Slack, PagerDuty, etc.)
                await SendToExternalSystems(severity, title, message, metadata);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to send alert: {Title}", title);
                _monitoring.TrackException(ex);
            }
        }

        private async Task SendToExternalSystems(string severity, string title, string message, Dictionary<string, object>? metadata)
        {
            // Implementation for sending alerts to external systems
            // This could include Teams webhooks, Slack, PagerDuty, etc.
            
            var webhookUrl = _configuration["Alerting:WebhookUrl"];
            if (!string.IsNullOrEmpty(webhookUrl))
            {
                using var httpClient = new HttpClient();
                var payload = new
                {
                    severity,
                    title,
                    message,
                    metadata,
                    timestamp = DateTime.UtcNow
                };

                var json = JsonSerializer.Serialize(payload);
                var content = new StringContent(json, Encoding.UTF8, "application/json");

                try
                {
                    await httpClient.PostAsync(webhookUrl, content);
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Failed to send alert to external system");
                }
            }
        }
    }
}