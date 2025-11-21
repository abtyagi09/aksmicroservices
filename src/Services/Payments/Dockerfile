FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
WORKDIR /app
EXPOSE 80
EXPOSE 443
EXPOSE 5003

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy project files
COPY ["src/Services/Payments/Payments.API/Payments.API.csproj", "src/Services/Payments/Payments.API/"]
COPY ["src/Services/Payments/Payments.Domain/Payments.Domain.csproj", "src/Services/Payments/Payments.Domain/"]
COPY ["src/Services/Payments/Payments.Infrastructure/Payments.Infrastructure.csproj", "src/Services/Payments/Payments.Infrastructure/"]
COPY ["src/Shared/Common/Shared.Common.csproj", "src/Shared/Common/"]

# Restore dependencies
RUN dotnet restore "src/Services/Payments/Payments.API/Payments.API.csproj"

# Copy source code
COPY . .
WORKDIR "/src/src/Services/Payments/Payments.API"

# Build application
RUN dotnet build "Payments.API.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "Payments.API.csproj" -c Release -o /app/publish /p:UseAppHost=false

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .

# Add health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:80/health || exit 1

ENTRYPOINT ["dotnet", "Payments.API.dll"]