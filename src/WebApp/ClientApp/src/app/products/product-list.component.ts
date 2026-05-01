import { Component, OnInit, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ProductService } from './product.service';
import { Product, CreateProductRequest } from './product.model';

@Component({
  selector: 'app-product-list',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <div class="card">
      <h2>Products</h2>

      <!-- Add Product Form -->
      <div class="add-form">
        <h3>Add New Product</h3>
        <div class="form-row">
          <input [(ngModel)]="newProduct.name" placeholder="Name" maxlength="200" />
          <input [(ngModel)]="newProduct.description" placeholder="Description" />
          <input [(ngModel)]="newProduct.price" type="number" min="0" step="0.01" placeholder="Price" />
          <button class="btn btn-primary" (click)="addProduct()" [disabled]="!newProduct.name">
            Add
          </button>
        </div>
      </div>

      <!-- Product Table -->
      <table>
        <thead>
          <tr>
            <th>ID</th>
            <th>Name</th>
            <th>Description</th>
            <th>Price</th>
            <th>Created</th>
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>
          @for (product of products(); track product.id) {
            <tr>
              <td>{{ product.id }}</td>
              <td>{{ product.name }}</td>
              <td>{{ product.description }}</td>
              <td>{{ product.price | currency }}</td>
              <td>{{ product.createdAt | date:'short' }}</td>
              <td>
                <button class="btn btn-danger" (click)="deleteProduct(product.id)">Delete</button>
              </td>
            </tr>
          }
        </tbody>
      </table>

      @if (products().length === 0) {
        <p class="empty-state">No products found. Add one above!</p>
      }
    </div>
  `,
  styles: [`
    .add-form { margin-bottom: 1.5rem; }
    .form-row {
      display: flex;
      gap: 0.5rem;
      flex-wrap: wrap;
    }
    .form-row input {
      padding: 0.5rem;
      border: 1px solid #edebe9;
      border-radius: 4px;
      font-size: 0.875rem;
    }
    .empty-state {
      text-align: center;
      color: #605e5c;
      padding: 2rem;
    }
  `],
})
export class ProductListComponent implements OnInit {
  private readonly productService = inject(ProductService);

  products = signal<Product[]>([]);
  newProduct: CreateProductRequest = { name: '', description: '', price: 0 };

  ngOnInit(): void {
    this.loadProducts();
  }

  loadProducts(): void {
    this.productService.getAll().subscribe({
      next: (data) => this.products.set(data),
      error: (err) => console.error('Failed to load products', err),
    });
  }

  addProduct(): void {
    if (!this.newProduct.name) return;
    this.productService.create(this.newProduct).subscribe({
      next: () => {
        this.newProduct = { name: '', description: '', price: 0 };
        this.loadProducts();
      },
      error: (err) => console.error('Failed to create product', err),
    });
  }

  deleteProduct(id: number): void {
    this.productService.delete(id).subscribe({
      next: () => this.loadProducts(),
      error: (err) => console.error('Failed to delete product', err),
    });
  }
}
