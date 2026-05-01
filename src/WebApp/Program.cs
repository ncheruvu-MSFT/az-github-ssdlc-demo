using SsdlcDemo.WebApp.Models;
using SsdlcDemo.WebApp.Services;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
builder.Services.AddApplicationInsightsTelemetry();
builder.Services.AddHealthChecks();
builder.Services.AddCors();
builder.Services.AddSingleton<IProductService, ProductService>();

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();
app.UseDefaultFiles();
app.UseStaticFiles();
app.MapHealthChecks("/health");
app.MapHealthChecks("/health/ready");

// ── Product API ─────────────────────────────────────────────────
var products = app.MapGroup("/api/products").WithOpenApi();

products.MapGet("/", (IProductService svc) =>
    Results.Ok(svc.GetAll()))
    .WithName("GetProducts");

products.MapGet("/{id:int}", (int id, IProductService svc) =>
{
    var product = svc.GetById(id);
    return product is not null ? Results.Ok(product) : Results.NotFound();
})
.WithName("GetProductById");

products.MapPost("/", (CreateProductRequest request, IProductService svc) =>
{
    if (string.IsNullOrWhiteSpace(request.Name) || request.Name.Length > 200)
    {
        return Results.BadRequest(new { error = "Name is required and must not exceed 200 characters." });
    }

    if (request.Price < 0)
    {
        return Results.BadRequest(new { error = "Price must be non-negative." });
    }

    var product = svc.Create(request);
    return Results.Created($"/api/products/{product.Id}", product);
})
.WithName("CreateProduct");

products.MapPut("/{id:int}", (int id, UpdateProductRequest request, IProductService svc) =>
{
    if (request.Name is not null && request.Name.Length > 200)
    {
        return Results.BadRequest(new { error = "Name must not exceed 200 characters." });
    }

    if (request.Price is < 0)
    {
        return Results.BadRequest(new { error = "Price must be non-negative." });
    }

    var updated = svc.Update(id, request);
    return updated is not null ? Results.Ok(updated) : Results.NotFound();
})
.WithName("UpdateProduct");

products.MapDelete("/{id:int}", (int id, IProductService svc) =>
{
    var deleted = svc.Delete(id);
    return deleted ? Results.NoContent() : Results.NotFound();
})
.WithName("DeleteProduct");

// ── Info endpoints ──────────────────────────────────────────────
app.MapGet("/api/info", () => Results.Ok(new
{
    Service = "SSDLC Demo WebApp",
    Environment = Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT") ?? "Unknown",
    DotNetVersion = Environment.Version.ToString(),
    Timestamp = DateTimeOffset.UtcNow,
}))
.WithName("Info")
.WithOpenApi();

app.MapFallbackToFile("index.html");

app.Run();

public partial class Program { }
