FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
WORKDIR /app
EXPOSE 80
EXPOSE 443
EXPOSE 5001

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy project files
COPY ["src/Services/NotificationServices/NotificationServices.API/NotificationServices.API.csproj", "src/Services/NotificationServices/NotificationServices.API/"]
COPY ["src/Services/NotificationServices/NotificationServices.Domain/NotificationServices.Domain.csproj", "src/Services/NotificationServices/NotificationServices.Domain/"]
COPY ["src/Services/NotificationServices/NotificationServices.Infrastructure/NotificationServices.Infrastructure.csproj", "src/Services/NotificationServices/NotificationServices.Infrastructure/"]
COPY ["src/Shared/Common/Shared.Common.Simple.csproj", "src/Shared/Common/"]

# Restore dependencies
RUN dotnet restore "src/Services/NotificationServices/NotificationServices.API/NotificationServices.API.csproj"

# Copy source code
COPY . .
WORKDIR "/src/src/Services/NotificationServices/NotificationServices.API"

# Build application
RUN dotnet build "NotificationServices.API.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "NotificationServices.API.csproj" -c Release -o /app/publish /p:UseAppHost=false

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .

# Add health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:80/health || exit 1

ENTRYPOINT ["dotnet", "NotificationServices.API.dll"]
