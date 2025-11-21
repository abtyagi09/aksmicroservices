FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
WORKDIR /app
EXPOSE 80
EXPOSE 443
EXPOSE 5002

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy project files
COPY ["src/Services/LoansUnderwriting/LoansUnderwriting.API/LoansUnderwriting.API.csproj", "src/Services/LoansUnderwriting/LoansUnderwriting.API/"]
COPY ["src/Services/LoansUnderwriting/LoansUnderwriting.Domain/LoansUnderwriting.Domain.csproj", "src/Services/LoansUnderwriting/LoansUnderwriting.Domain/"]
COPY ["src/Services/LoansUnderwriting/LoansUnderwriting.Infrastructure/LoansUnderwriting.Infrastructure.csproj", "src/Services/LoansUnderwriting/LoansUnderwriting.Infrastructure/"]
COPY ["src/Shared/Common/Shared.Common.csproj", "src/Shared/Common/"]

# Restore dependencies
RUN dotnet restore "src/Services/LoansUnderwriting/LoansUnderwriting.API/LoansUnderwriting.API.csproj"

# Copy source code
COPY . .
WORKDIR "/src/src/Services/LoansUnderwriting/LoansUnderwriting.API"

# Build application
RUN dotnet build "LoansUnderwriting.API.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "LoansUnderwriting.API.csproj" -c Release -o /app/publish /p:UseAppHost=false

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .

# Add health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:80/health || exit 1

ENTRYPOINT ["dotnet", "LoansUnderwriting.API.dll"]