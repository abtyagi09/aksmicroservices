FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
WORKDIR /app
EXPOSE 80
EXPOSE 443
EXPOSE 5001

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy project files
COPY ["src/Services/MemberServices/MemberServices.API/MemberServices.API.csproj", "src/Services/MemberServices/MemberServices.API/"]
COPY ["src/Services/MemberServices/MemberServices.Domain/MemberServices.Domain.csproj", "src/Services/MemberServices/MemberServices.Domain/"]
COPY ["src/Services/MemberServices/MemberServices.Infrastructure/MemberServices.Infrastructure.csproj", "src/Services/MemberServices/MemberServices.Infrastructure/"]
COPY ["src/Shared/Common/Shared.Common.csproj", "src/Shared/Common/"]

# Restore dependencies
RUN dotnet restore "src/Services/MemberServices/MemberServices.API/MemberServices.API.csproj"

# Copy source code
COPY . .
WORKDIR "/src/src/Services/MemberServices/MemberServices.API"

# Build application
RUN dotnet build "MemberServices.API.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "MemberServices.API.csproj" -c Release -o /app/publish /p:UseAppHost=false

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .

# Add health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:80/health || exit 1

ENTRYPOINT ["dotnet", "MemberServices.API.dll"]