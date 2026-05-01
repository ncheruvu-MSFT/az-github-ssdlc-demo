using System.Collections.Concurrent;
using SsdlcDemo.WebApp.Models;

namespace SsdlcDemo.WebApp.Services;

public interface IProductService
{
    IReadOnlyList<Product> GetAll();
    Product? GetById(int id);
    Product Create(CreateProductRequest request);
    Product? Update(int id, UpdateProductRequest request);
    bool Delete(int id);
}

public sealed class ProductService : IProductService
{
    private readonly ConcurrentDictionary<int, Product> _products = new();
    private int _nextId = 1;

    public ProductService()
    {
        // Seed sample data
        Create(new CreateProductRequest("Azure Functions Guide", "Comprehensive guide to serverless on Azure", 29.99m));
        Create(new CreateProductRequest("Container Security Playbook", "SSDLC best practices for container workloads", 49.99m));
        Create(new CreateProductRequest("DevOps Starter Kit", "CI/CD templates and pipeline examples", 19.99m));
    }

    public IReadOnlyList<Product> GetAll() =>
        _products.Values.OrderBy(p => p.Id).ToList();

    public Product? GetById(int id) =>
        _products.GetValueOrDefault(id);

    public Product Create(CreateProductRequest request)
    {
        var id = Interlocked.Increment(ref _nextId);
        var product = new Product(id, request.Name, request.Description, request.Price, DateTimeOffset.UtcNow);
        _products[id] = product;
        return product;
    }

    public Product? Update(int id, UpdateProductRequest request)
    {
        if (!_products.TryGetValue(id, out var existing))
        {
            return null;
        }

        var updated = existing with
        {
            Name = request.Name ?? existing.Name,
            Description = request.Description ?? existing.Description,
            Price = request.Price ?? existing.Price,
        };

        _products[id] = updated;
        return updated;
    }

    public bool Delete(int id) =>
        _products.TryRemove(id, out _);
}
