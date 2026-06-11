# syntax=docker/dockerfile:1
###############################################################################
# Dockerfile — API TicketGo (ASP.NET Core)
# Multi-stage build para imagen mínima y segura en producción
###############################################################################

# ── Etapa 1: Build ────────────────────────────────────────────────────────────
FROM mcr.microsoft.com/dotnet/sdk:8.0-alpine AS build
WORKDIR /src

# Copiar proyecto y restaurar dependencias (cacheado si .csproj no cambia)
COPY ["TicketGo.Api.csproj", "."]
RUN dotnet restore "TicketGo.Api.csproj" --runtime linux-musl-x64

# Copiar el resto y compilar en modo Release
COPY . .
RUN dotnet publish "TicketGo.Api.csproj" \
    -c Release \
    -r linux-musl-x64 \
    --self-contained false \
    -o /app/publish \
    /p:UseAppHost=false

# ── Etapa 2: Runtime ──────────────────────────────────────────────────────────
FROM mcr.microsoft.com/dotnet/aspnet:8.0-alpine AS runtime
WORKDIR /app

# Seguridad: usuario no-root para el proceso de la aplicación
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser

# Copiar solo el artefacto compilado
COPY --from=build --chown=appuser:appgroup /app/publish .

# Puerto de escucha (debe coincidir con container_port en Terraform)
EXPOSE 8080
ENV ASPNETCORE_URLS="http://+:8080"

# Health check integrado en el contenedor
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD wget -qO- http://localhost:8080/health || exit 1

ENTRYPOINT ["dotnet", "TicketGo.Api.dll"]
