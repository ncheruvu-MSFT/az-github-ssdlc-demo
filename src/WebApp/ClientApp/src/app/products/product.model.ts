export interface Product {
  id: number;
  name: string;
  description: string;
  price: number;
  createdAt: string;
}

export interface CreateProductRequest {
  name: string;
  description: string;
  price: number;
}
