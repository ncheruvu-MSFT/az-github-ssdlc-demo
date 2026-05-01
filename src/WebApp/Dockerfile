# --- Build Angular ---
FROM node:20-alpine AS angular-build
WORKDIR /app
COPY ClientApp/package.json ClientApp/package-lock.json* ./
RUN npm install --ignore-scripts
COPY ClientApp/ .
RUN npm run build -- --configuration production

# --- Build .NET ---
FROM mcr.microsoft.com/dotnet/sdk:8.0-alpine AS dotnet-build
ARG BUILD_CONFIGURATION=Release
WORKDIR /src
COPY ["SsdlcDemo.WebApp.csproj", "."]
RUN dotnet restore "SsdlcDemo.WebApp.csproj"
COPY . .
COPY --from=angular-build /app/dist/ssdlc-demo-webapp/browser ./wwwroot
RUN dotnet build "SsdlcDemo.WebApp.csproj" -c $BUILD_CONFIGURATION -o /app/build

FROM dotnet-build AS publish
ARG BUILD_CONFIGURATION=Release
RUN dotnet publish "SsdlcDemo.WebApp.csproj" -c $BUILD_CONFIGURATION -o /app/publish /p:UseAppHost=false

# --- Runtime ---
FROM mcr.microsoft.com/dotnet/aspnet:8.0-alpine AS final
WORKDIR /app
EXPOSE 8080

# Security: non-root user (SSDLC requirement)
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser

COPY --from=publish /app/publish .
ENV ASPNETCORE_URLS=http://+:8080
ENTRYPOINT ["dotnet", "SsdlcDemo.WebApp.dll"]
