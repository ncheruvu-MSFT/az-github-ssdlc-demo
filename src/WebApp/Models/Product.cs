namespace SsdlcDemo.WebApp.Models;

public sealed record Product(int Id, string Name, string Description, decimal Price, DateTimeOffset CreatedAt);

public sealed record CreateProductRequest(string Name, string Description, decimal Price);

public sealed record UpdateProductRequest(string? Name, string? Description, decimal? Price);
