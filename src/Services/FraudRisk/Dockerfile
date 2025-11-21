FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
WORKDIR /app
EXPOSE 80
EXPOSE 443
EXPOSE 5004

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy project files
COPY ["src/Services/FraudRisk/FraudRisk.API/FraudRisk.API.csproj", "src/Services/FraudRisk/FraudRisk.API/"]
COPY ["src/Services/FraudRisk/FraudRisk.Domain/FraudRisk.Domain.csproj", "src/Services/FraudRisk/FraudRisk.Domain/"]
COPY ["src/Services/FraudRisk/FraudRisk.Infrastructure/FraudRisk.Infrastructure.csproj", "src/Services/FraudRisk/FraudRisk.Infrastructure/"]
COPY ["src/Shared/Common/Shared.Common.csproj", "src/Shared/Common/"]

# Restore dependencies
RUN dotnet restore "src/Services/FraudRisk/FraudRisk.API/FraudRisk.API.csproj"

# Copy source code
COPY . .
WORKDIR "/src/src/Services/FraudRisk/FraudRisk.API"

# Build application
RUN dotnet build "FraudRisk.API.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "FraudRisk.API.csproj" -c Release -o /app/publish /p:UseAppHost=false

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .

# Add health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:80/health || exit 1

ENTRYPOINT ["dotnet", "FraudRisk.API.dll"]